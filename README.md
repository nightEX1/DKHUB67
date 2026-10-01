# DKHUB67

## DKHUB EggWarpUI v2.6

ไฟล์หลัก: `DKHUBV2_2.6.lua`

ความสามารถ:

- สวิตช์ **ออโต้หาไข่** วาร์ปวนหาไข่ทุก 60 วินาที
- ข้าม `White Egg`, `Brown Egg`, `Cracked Egg`, `Easter Egg`, `Stone Egg`
- `Leaf Egg` ยังอยู่ในโหมดออโต้และเลือกแจ้งเตือนได้
- ช่องกรอก Discord Webhook
- ปุ่มเลือกไข่ที่ต้องการแจ้งเตือน
- Webhook ส่งชื่อไข่ น้ำหนัก และภาพไข่ผ่าน Discord embed
- ไม่ต้องกดปุ่มวาร์ปทีละรายการแล้ว

ระบบภาพจะใช้ไฟล์ local ก่อน หากไม่มีจะดาวน์โหลดจาก GitHub Raw อัตโนมัติด้วย `game:HttpGet` และ `writefile`
