# Adding Widget Extension in Xcode

1. Open ChefPro.xcodeproj in Xcode
2. File → New → Target
3. Choose "Widget Extension"
4. Product Name: ChefProWidget
5. Bundle Identifier: com.yourcompany.chefpro.widget
6. Include Live Activity: No
7. Click Finish
8. IMPORTANT: Delete the auto-generated files Xcode creates
9. Add App Group capability to both ChefPro and ChefProWidget targets:
   - Select ChefPro target → Signing & Capabilities → + Capability → App Groups
   - Add group.com.chefpro.app
   - Do the same for ChefProWidget target
10. The source files in ChefProWidget/ folder will be used automatically
