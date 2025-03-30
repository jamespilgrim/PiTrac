**Description:**

A 3D-printed mount that secures an LED array with a lens in front of the LED. An example infrared LED is: [High Power LED Chip IR 850nm 100W COB Integrated Matrix Light Beads for Night Vision Camera](https://www.amazon.com/dp/B09DPJYRQN?ref=ppx_yo2ov_dt_b_product_details&th=1), and an example lens is: [60 / 120 Degree LED Lens Optical Glass 44mm + Reflector Collimator + Fixed Bracket for 20W 30W 50W 100W COB High Power Chip (60Degree 100W lens kit](https://www.amazon.com/dp/B09XK7QTV5?ref=ppx_yo2ov_dt_b_fed_asin_title)).

**WARNING: This mount is not designed for high temperatures, and would melt if a high-power (>= 20W) LED array was left on for any more than a second or so. There is no room for a heat sink. This mount is intended ONLY for an LED that is operated as a very short-pulse strobe light, where the LED is powered for only a few milliseconds per second and with a very low duty cycle. Ensure that the LED is not inadvertently powered.**

The mount can tilt up/down and swivel around a bolt that attaches the base of the mount to a flat surface. A [FreeCAD 1.0](https://www.freecad.org/downloads.php) compatible parameterized model is included here along with .stl files.

The [DIY golf launch monitor project](https://hackaday.io/project/195042-diy-golf-launch-monitor) is using this mount for its infrared strobe light that helps capture the stop-motion images for the monitor. The mount assumes that the power wires that go to the LED will be attached to the sides of the array (see image of printed part).

Please consider supporting this work and the DIY LM project here: <https://ko-fi.com/jamespilgrim>

**Printing Notes:**

PLA or PETG works well with this mount.

Recommended print settings: 4 perimeter layers (less if the bolts are not expected to be tightened very much), 15% infill, grid infill patterns, no supports. See .3mf file. Does not required glue-stick or brim assists.

**Parts Needed for Assembly:**

| **Quantity** | **Hardware** | **Purpose** |
| --- | --- | --- |
| 4 each | M3 x 10mm self-tapping screws | LED Array Attachment Screws (array to back plate) |
| --- | --- | --- |
| 4 each | M3 x 10mm self-tapping screws | LED Lens Holder Attachment Screws (lens to back plate) |
| --- | --- | --- |
| 2 each | M4 x 12mm <br><br>M4 Hex Nuts | Strobe Gimbal Attachment Hinge |
| --- | --- | --- |
| 1 each | M5 x 12<br><br>M5 Hex Nut | Strobe (Pan) Swivel Mount (on bottom of mount) |
| --- | --- | --- |

Also required is the LED array and lens (see example suppliers, above).

**Note:** For the screws, stainless steel seems to be stronger than black carbon steel, though both can work. Especially in the stiffer PLA material, stainless is preferable because black carbon can break if torqued too much. For parts supply examples see [HanTof 525 Pcs 304 Stainless Steel M2 M3 M4 Phillips Pan Head Self Tapping Wood screws Assortment Kit](https://www.googleadservices.com/pagead/aclk?sa=L&ai=DChcSEwiLuLi4w9eJAxW8Ka0GHe7XF-QYABALGgJwdg&co=1&ase=2&gclid=Cj0KCQiAlsy5BhDeARIsABRc6ZvLmaSF7SMXMVEWsWj3rp8S5qOvISkRMdr9czJDXK6-_GcV_X18lyoaApxdEALw_wcB&ohost=www.google.com&cid=CAESVeD2Qt_A3T4eLbWpcXoKb1T4jyPt8OTe6U2I9Uze-kjy3MAArJhoS9pYvi39aDroogjezyRvCcOJ56x4hYKkL8BaTouv69VFkW3lUm7VcRcYOp8m49s&sig=AOD64_3FizAX65usODanOujaKxqh5_gQbg&ctype=5&q=&nis=4&ved=2ahUKEwj92Kq4w9eJAxU1JzQIHakTKO8Q9aACKAB6BAgEEAw&adurl=)., mxuteuk M2.5 Screw Assortment Set,M2.5 x 4/6/8/10/12/16/20/25mm Hex Socket Head Cap Screws Bolts Nuts Kit,400PCS 304 Stainless Steel Assorted Screws with Hex Wrench G035-M2.5, and [Besitu 1760pcs M2 M3 M4 M5 Metric Screw Assortment, Grade 12.9 Alloy Steel Hex Socket Head Cap Metric Bolts and Nuts Kit, Black Zinc Plated and Anti Rust Metric Screw Set with 4 pcs Hex Wrenches](https://www.amazon.com/dp/B0C38YFL3D?ref=ppx_yo2ov_dt_b_fed_asin_title)

**Assembly Notes:**

Start by placing the three nuts in their recessed positions on the two sides of the backplate and the one nut in the top of the base. It is easier to place each of the three nuts into its respective indent, and then temporarily place a strip of easy-to-remove tape (e.g., scotch) over the nut to keep it in place while assembling the mount.

If not already done, securely solder the two power lead wires to the LED array. Make sure that the positive and negative terminals and wires are clearly (and correctly!) labelled.

Mount the LED array to the backplate using four M3 self-tapping screws. Avoid touching the LEDs in the process. Run the power wires through the clips on either side of the top of the mount. It’s best to have these wires terminated in a quick-connect like an [Ideal Industries 30-102 Power Plug](https://www.amazon.com/Ideal-Industries-30-102-Power-72427/dp/B01LYF1WV9/ref=sr_1_10?crid=35QTOVMFFT8MM&dib=eyJ2IjoiMSJ9.E2lbqLFKVG_hmleCqoMKymmILpx7xHQqbjKLlS_O8biic815YLA-1NACjC7tLtjM1exKso1Yz_65dH1SEbMni2IVp4idBpijPJhdQ_dqc_jCaEmkTbkPx0xoOe5u_wFYZDU-708_oXsrAmTNBXO-a2iAVH3lMZzeo9MZ6zFEO29IgxN_2m_0GrCkWTMORn0iifYao1peHnHenuPGSKCOTzvpolrumaoD-CkeZ5nvs29wAsiRDyq-Yq2K7tfmSzrQslG_ZpLzrx5-9GZQe55ktJDEK1bqKpEjHi-F_Lg1tuk.lAcQi1tp-upRzLoq8eleSXFSf1Vet_Xild25OSMBkYI&dib_tag=se&keywords=ideal+power+plug&qid=1732650183&sprefix=ideal+power+plug%2Caps%2C174&sr=8-10).

Next, place the lens standoff/riser, lens, and lens holder bracket on top of the array, making sure that the mirrored separate between the LED and the lens is centered and appropriately aligned.

Then mount the lens to the backplate using four more M3 self-tapping screws. **IMPORTANT: Only tighten the screws enough to secure the holder bracket against the lens and mirrored riser. There will be a gab between the bracket and the plastic risers that accept the screws of the mount. This is by design. Over-tightening can crack or break the lens, standoff, and/or LED itself. Note the gap in the annotated print part image.**

Mount the backplate to the gimbal base using 2 M4 bolts. Finally, secure the entire mount to whatever base will hold it by using an M5 bolt.

The mount’s tilt and pan angles will generally stay put once the nuts are tightened, simply based on the friction between the parts. If the angles cannot be finely tuned, sanding the parts helps.