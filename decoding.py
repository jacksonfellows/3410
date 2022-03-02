instructions = {
    "ADD":  [0b0000011],
    "SUB":  [0b1000011],
    "AND":  [0b0111011],
    "OR":   [0b0110011],
    "XOR":  [0b0100011],
    "SLT":  [0b0010011],
    "SLL":  [0b0001011],
    "SRA":  [0b1101011],
    "ADDI": [0b0000001,
             0b1000001],
    "ANDI": [0b0111001,
             0b1111001],
    "ORI":  [0b0110001,
             0b1110001],
    "XORI": [0b0100001,
             0b1100001],
    "SLTI": [0b0010001,
             0b1010001],
    "LW":   [0b0010000,
             0b1010000],
    "LB":   [0b0000000,
             0b1000000],
    "SW":   [0b0010010,
             0b1010010],
    "SB":   [0b0000010,
             0b1000010]
}

alu_opcodes = {
    "and": "1111",
    "or":  "1110",
    "sll": "001x",
    "xor": "1100",
    "sra": "0111",
    "sub": "010x",
    "add": "000x"
}

inst_to_alu = {
    "ADD":  "add",
    "SUB":  "sub",
    "AND":  "and",
    "OR":   "or",
    "XOR":  "xor",
    "SLL":  "sll",
    "SRA":  "sra",
    "ADDI": "add",
    "ANDI": "and",
    "ORI":  "or",
    "XORI": "xor",
    "LW":   "add",
    "LB":   "add",
    "SW":   "add",
    "SB":   "add"
}

def instructions_for(op):
    return [inst for inst,op_ in inst_to_alu.items() if op_ == op]

from sympy.logic import SOPform, POSform
from sympy import symbols

bit_syms = symbols('b30 b13 b12 b11 b6 b5 b4')

def nth_bit(n):
    minterms = []
    do_cares = []
    for op,code in alu_opcodes.items():
        insts = instructions_for(op)
        bit = code[n]
        if bit != "x":
            for inst in insts:
                for x in instructions[inst]:
                    if bit == "0":
                        do_cares.append(x)
                    elif bit == "1":
                        minterms.append(x)
    dont_cares = []
    for i in range(1 << 7):
        if i not in do_cares and i not in minterms:
            dont_cares.append(i)
    # print(f'bit_syms: {bit_syms}')
    # print(f'minterms: {minterms}')
    # print(f'dont_cares: {dont_cares}')
    return SOPform(bit_syms, minterms, dont_cares)
