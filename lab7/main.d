00010374 <main>:
   10374:	fd010113          	addi	sp,sp,-48
   10378:	02112623          	sw	ra,44(sp)
   1037c:	02812423          	sw	s0,40(sp)
   10380:	03010413          	addi	s0,sp,48
   10384:	fca42e23          	sw	a0,-36(s0)
   10388:	fcb42c23          	sw	a1,-40(s0)
   1038c:	00700593          	li	a1,7
   10390:	000117b7          	lui	a5,0x11
   10394:	3e478513          	addi	a0,a5,996 # 113e4 <a>
   10398:	f71ff0ef          	jal	ra,10308 <weird_function>
   1039c:	fea42623          	sw	a0,-20(s0)
   103a0:	000107b7          	lui	a5,0x10
   103a4:	3d878513          	addi	a0,a5,984 # 103d8 <main+0x64>
   103a8:	d15ff0ef          	jal	ra,100bc <prints>
   103ac:	fec42503          	lw	a0,-20(s0)
   103b0:	ce5ff0ef          	jal	ra,10094 <printi>
   103b4:	000107b7          	lui	a5,0x10
   103b8:	3e078513          	addi	a0,a5,992 # 103e0 <main+0x6c>
   103bc:	d01ff0ef          	jal	ra,100bc <prints>
   103c0:	00000793          	li	a5,0
   103c4:	00078513          	mv	a0,a5
   103c8:	02c12083          	lw	ra,44(sp)
   103cc:	02812403          	lw	s0,40(sp)
   103d0:	03010113          	addi	sp,sp,48
   103d4:	00008067          	ret
