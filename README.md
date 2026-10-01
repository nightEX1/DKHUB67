# DKHUB67

## DKHUB EggWarpUI v2.5

ไฟล์หลัก: `DKHUBV2_2.5.lua`

ใน v2.5 ตัดไข่ต่อไปนี้ออกจาก `EggNames` แล้ว:

- White Egg
- Brown Egg
- Cracked Egg
- Easter Egg
- Stone Egg
- Leaf Egg

ภาพไข่ทั้งหมดถูกเก็บไว้ใน `DKHUB_Eggs/` และสคริปต์จะใช้ไฟล์ local ก่อน หากไม่พบไฟล์จะดาวน์โหลดจาก GitHub Raw อัตโนมัติด้วย `game:HttpGet` แล้วบันทึกด้วย `writefile` เพื่อแสดงผ่าน `getcustomasset`/`getsynasset`
