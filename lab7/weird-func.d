00010308 <weird_function>:
   10308:	fd010113          	addi	sp,sp,-48
   1030c:	02812623          	sw	s0,44(sp)
   10310:	03010413          	addi	s0,sp,48
   10314:	fca42e23          	sw	a0,-36(s0)
   10318:	fcb42c23          	sw	a1,-40(s0)
   1031c:	fe042423          	sw	zero,-24(s0)
   10320:	fe042623          	sw	zero,-20(s0)
   10324:	0300006f          	j	10354 <weird_function+0x4c>
   10328:	fec42783          	lw	a5,-20(s0)
   1032c:	00279793          	slli	a5,a5,0x2
   10330:	fdc42703          	lw	a4,-36(s0)
   10334:	00f707b3          	add	a5,a4,a5
   10338:	0007a783          	lw	a5,0(a5)
   1033c:	fe842703          	lw	a4,-24(s0)
   10340:	00f707b3          	add	a5,a4,a5
   10344:	fef42423          	sw	a5,-24(s0)
   10348:	fec42783          	lw	a5,-20(s0)
   1034c:	00178793          	addi	a5,a5,1
   10350:	fef42623          	sw	a5,-20(s0)
   10354:	fec42703          	lw	a4,-20(s0)
   10358:	fd842783          	lw	a5,-40(s0)
   1035c:	fcf746e3          	blt	a4,a5,10328 <weird_function+0x20>
   10360:	fe842783          	lw	a5,-24(s0)
   10364:	00078513          	mv	a0,a5
   10368:	02c12403          	lw	s0,44(sp)
   1036c:	03010113          	addi	sp,sp,48
   10370:	00008067          	ret
