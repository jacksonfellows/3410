Jackson Fellows (jf787)


Critical path:

Add1: 2
Add32: 32*Add1 + 1 = 65 for V, 32*Add1 = 64 for C
LeftShift1/2/4/8/16: 2
LeftShift32: LeftShift1 + LeftShift2 + LeftShift4 + LeftShift8 + LeftShift16 = 10
Cmp32: 1 + 2 + 1 + 1 + 2 + 1 (ignoring sign extender) = 8
AddSub32: 1 + Add32 = 66 for V, 65 for C
LeftRightShift32: 2 + LeftShift32 + 2 = 14
ALU32: AddSub32 + 2 + 2 = 65 + 2 + 2 = 69

Total critical path is 69.


Gate count:

Add1: 9
Add32: 32*Add1 + 1 = 65
LeftShift1/2/4/8/16: 32*3 = 96
LeftShift32: LeftShift1 + LeftShift2 + LeftShift4 + LeftShift8 + LeftShift16 = 480
Cmp32: 32 + 32*3 + 1 + 1 + 1*3 + 1 = 134
AddSub32: 32 + Add32 = 97
LeftRightShift32: 32*3 + 1 + LeftShift32 + 32*3 = 673
ALU32: LeftRightShift32 + AddSub32 + Cmp32 + 32 + 32 + 32 + 32 + 8*32*3 + 1 = 1801

Total gate count is 1801.
