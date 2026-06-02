const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ── Secrets (set via: firebase functions:secrets:set SMTP_USER) ───────────
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");
const REPORT_TO = defineSecret("REPORT_EMAIL");

// ─────────────────────────────────────────────────────────────────────────────
// 1. WEEKLY FOOD COST REPORT
//    Runs every Monday at 09:00 Moscow time (UTC+3 = 06:00 UTC).
//    Iterates all restaurants, calculates food cost % for the past 7 days,
//    and sends an email to the address stored in each restaurant's profile.
// ─────────────────────────────────────────────────────────────────────────────
exports.weeklyFoodCostReport = onSchedule(
  {
    schedule: "0 6 * * 1",   // every Monday 06:00 UTC
    timeZone: "Europe/Moscow",
    secrets: [SMTP_USER, SMTP_PASS, REPORT_TO],
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const weekAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 7 * 24 * 60 * 60 * 1000
    );

    const restaurants = await db.collection("restaurants").listDocuments();

    for (const restRef of restaurants) {
      try {
        await processRestaurantReport(restRef, weekAgo, now);
      } catch (e) {
        console.error(`Report failed for ${restRef.id}:`, e);
      }
    }
  }
);

async function processRestaurantReport(restRef, from, to) {
  const [profileSnap, writeOffsSnap, deliveriesSnap] = await Promise.all([
    restRef.collection("profile").doc("current").get(),
    restRef.collection("writeOffs").where("date", ">=", from).where("date", "<=", to).get(),
    restRef.collection("deliveries").where("date", ">=", from).where("date", "<=", to).get(),
  ]);

  const profile = profileSnap.data() || {};
  const email = profile.email || REPORT_TO.value();
  const restaurantName = profile.restaurantName || restRef.id;
  const monthlyRevenue = profile.monthlyRevenuePlan || 0;
  const weeklyRevenue = monthlyRevenue / 4.33;

  // Sum write-off costs
  let writeOffTotal = 0;
  writeOffsSnap.forEach((doc) => {
    const d = doc.data();
    writeOffTotal += (d.quantity || 0) * (d.pricePerUnit || 0);
  });

  // Sum delivery costs
  let deliveryTotal = 0;
  deliveriesSnap.forEach((doc) => {
    const d = doc.data();
    deliveryTotal += d.totalAmount || 0;
  });

  const foodCostAmount = writeOffTotal + deliveryTotal;
  const foodCostPct = weeklyRevenue > 0 ? (foodCostAmount / weeklyRevenue) * 100 : 0;

  const subject = `[ChefPro] Еженедельный отчёт — ${restaurantName}`;
  const body = `
<h2>Еженедельный отчёт по Food Cost</h2>
<p><b>Ресторан:</b> ${restaurantName}</p>
<p><b>Период:</b> последние 7 дней</p>
<hr/>
<table>
  <tr><td>Списания</td><td><b>${writeOffTotal.toFixed(2)} ₽</b></td></tr>
  <tr><td>Закупки</td><td><b>${deliveryTotal.toFixed(2)} ₽</b></td></tr>
  <tr><td>Итого затрат</td><td><b>${foodCostAmount.toFixed(2)} ₽</b></td></tr>
  <tr><td>Плановая выручка (нед.)</td><td><b>${weeklyRevenue.toFixed(2)} ₽</b></td></tr>
  <tr><td><b>Food Cost %</b></td><td><b style="color:${foodCostPct > 35 ? 'red' : 'green'}">${foodCostPct.toFixed(1)}%</b></td></tr>
</table>
<hr/>
<p style="color:gray;font-size:12px">Отчёт сформирован автоматически ChefPro</p>
  `.trim();

  await sendEmail(email, subject, body);

  // Save report snapshot to Firestore for history
  await restRef.collection("weeklyReports").add({
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    periodFrom: from,
    periodTo: to,
    writeOffTotal,
    deliveryTotal,
    foodCostAmount,
    foodCostPct,
    weeklyRevenue,
  });
}

async function sendEmail(to, subject, html) {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user: SMTP_USER.value(), pass: SMTP_PASS.value() },
  });
  await transporter.sendMail({ from: SMTP_USER.value(), to, subject, html });
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AUTO-ARCHIVE OLD RECORDS
//    Runs every day at 02:00 UTC.
//    Moves write-offs and deliveries older than 90 days to the
//    `archive/{year}/{collection}` sub-collection and deletes the originals.
//    This keeps active collections small and reads fast.
// ─────────────────────────────────────────────────────────────────────────────
exports.archiveOldRecords = onSchedule(
  { schedule: "0 2 * * *", timeZone: "UTC" },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 90 * 24 * 60 * 60 * 1000
    );
    const restaurants = await db.collection("restaurants").listDocuments();

    for (const restRef of restaurants) {
      for (const col of ["writeOffs", "deliveries", "productions"]) {
        await archiveCollection(restRef, col, cutoff);
      }
    }
  }
);

async function archiveCollection(restRef, collectionName, cutoff) {
  const snap = await restRef
    .collection(collectionName)
    .where("date", "<", cutoff)
    .limit(400) // process in batches to stay under Firestore limits
    .get();

  if (snap.empty) return;

  const year = new Date().getFullYear();
  const archiveRef = restRef
    .collection("archive")
    .doc(String(year))
    .collection(collectionName);

  const batch = db.batch();
  snap.forEach((doc) => {
    batch.set(archiveRef.doc(doc.id), doc.data());
    batch.delete(doc.ref);
  });
  await batch.commit();
  console.log(`Archived ${snap.size} docs from ${restRef.id}/${collectionName}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. NEW MEMBER REGISTRATION
//    Triggered when a device writes its UID to restaurants/{id}/members/{uid}.
//    Stamps the join timestamp so we have an audit trail.
// ─────────────────────────────────────────────────────────────────────────────
exports.onMemberJoined = onDocumentWritten(
  "restaurants/{restaurantID}/members/{uid}",
  async (event) => {
    if (!event.data.after.exists) return; // document deleted — ignore
    await event.data.after.ref.set(
      { joinedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  }
);
