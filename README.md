# DKHUB67

## DKHUB EggWarpUI v2.4

ไฟล์หลัก: `DKHUBV2_2.4.lua`

สคริปต์จะพยายามโหลดภาพจากไฟล์ local ก่อน หากไม่มีไฟล์ จะดาวน์โหลดจาก GitHub Raw อัตโนมัติด้วย `game:HttpGet` และบันทึกด้วย `writefile` จากนั้นใช้ `getcustomasset`/`getsynasset` แสดงภาพใน UI

ภาพที่เชื่อมกับสคริปต์:

- `DKHUB_Logo.png`
- `DKHUB_Eggs/*.png`

ถ้า executor รองรับฟังก์ชันดังกล่าว เมื่อลิงก์สคริปต์ไปรันครั้งแรก ระบบจะดาวน์โหลดภาพเอง ไม่ต้องเตรียมโฟลเดอร์ภาพด้วยมือ
