import re
import itertools
from pyvis.network import Network

def reg_num(r):
    if r.startswith('x'):
        return int(r[1:])
    if r.startswith('a'):
        return 10 + int(r[1:])
    if r == 's0':
        return 8
    if r == 'zero':
        return 0
    if r == 'sp':
        return 2
    raise ValueError('Cannot parse register ' + r)

def parse_inst(inst):
    op, *rest = inst.split()
    if len(rest) == 0:
        return (op,)
    base = 16 if op == 'j' or op.startswith('b') else 10
    args = [a.split()[0] for a in ' '.join(rest).split(',')]
    r = [op]
    for arg in args:
        m = re.match('^(-?[0-9]+)\(([a-z]+[0-9]*)\)$', arg)
        if m:
            imm, reg = m.groups()
            r.append(reg_num(reg))
            r.append(int(imm, base))
        else:
            if re.match('[a-z]+[0-9]*', arg):
                r.append(reg_num(arg))
            else:
                if arg.startswith('0x'):
                    r.append(int(arg, 16))
                else:
                    r.append(int(arg, base))
    return tuple(r)

def branches(op):
    return op == 'j' or op.startswith('b')

def print_inst(inst):
    return f'{inst[0]} {",".join(map(str,inst[1:]))}'

def print_expr(expr):
    if expr[0] == 'add':
        return f'{print_expr(expr[1])} + {print_expr(expr[2])}'
    if expr[0] == 'sll':
        return f'{print_expr(expr[1])} << {print_expr(expr[2])}'
    if expr[0] == 'local':
        return f'local{expr[1]}'
    if expr[0] == 'const':
        return expr[1]
    if expr[0] == 'lw' and expr[1][0] == 'add':
        return f'{print_expr(expr[1][1])}[{print_expr(expr[1][2])}]'
    if expr[0] == 'arg':
        return f'arg{expr[1]}'
    raise ValueError(f'Cannot print expr {expr}')

class Program:
    def __init__(self, fname):
        self.first_address = None
        self.code = []
        with open(fname) as f:
            for line in f.readlines():
                m = re.match('^\s*([0-9a-f]+):\s+[0-9a-f]{8}\s+([^#]+)(?:#.*)?$', line)
                if m:
                    address, inst = m.groups()
                    if self.first_address is None:
                        self.first_address = int(address, 16)
                    self.code.append(parse_inst(inst))
        self.cfg = {}
        self.make_cfg()

    def get_inst(self, address):
        return self.code[(address - self.first_address)//4]

    def make_cfg(self):
        for i,inst in enumerate(self.code):
            address = self.first_address + 4*i
            if inst[0] == 'j':
                self.cfg[address] = (inst[1],)
            elif inst[0].startswith('b'):
                self.cfg[address] = (inst[2 if inst[0] == 'bnez' else 3], address+4)
            elif inst[0] == 'jal':
                raise ValueError('jal not supported')
            else:
                if i != len(self.code) - 1:
                    self.cfg[address] = (address+4,)

    def to_network(self):
        net = Network(height='1000px', width='1000px')
        net.add_nodes([self.first_address + 4*i for i in range(len(self.code))], label=[print_inst(inst) for inst in self.code])
        for address,targets in self.cfg.items():
            if len(targets) == 2:
                # conditional branch
                net.add_edge(address, targets[0], label='true')
                net.add_edge(address, targets[1], label='false')
            else:
                for target in targets:
                    net.add_edge(address, target)
        net.set_options('{"edges": {"arrows": {"to": {"enabled": true}}, "color": {"inherit": true}, "smooth": false}, "layout": {"hierarchical": {"enabled": true, "sortMethod": "directed"}}, "physics": {"hierarchicalRepulsion": {"centralGravity": 0}, "minVelocity": 0.75, "solver": "hierarchicalRepulsion"}}')
        return net

    def dest(self, address):
        return len([x for x in itertools.chain(*self.cfg.values()) if x == address]) > 1

    def find_basic_blocks(self, start, end):
        blocks = []
        block = []
        for i,inst in enumerate(self.code[start:end]):
            address = self.first_address + 4*(start + i)
            if self.dest(address):
                blocks.append(block)
                block = []
            block.append(address)
            if branches(inst[0]):
                blocks.append(block)
                block = []
        blocks.append(block)
        return blocks

    def to_c(self):
        # expand stack
        assert(self.code[0][0] == 'addi')
        assert(self.code[0][1] == reg_num('sp'))
        assert(self.code[0][2] == reg_num('sp'))
        stack_size = -self.code[0][3]
        # save s0
        assert(self.code[1][0] == 'sw')
        assert(self.code[1][1] == reg_num('s0'))
        assert(self.code[1][2] == reg_num('sp'))
        # change s0
        assert(self.code[2] == ('addi', reg_num('s0'), reg_num('sp'), stack_size))
        # reset s0
        assert(self.code[-3] == ('lw', reg_num('s0'), reg_num('sp'), stack_size-4))
        # reset sp
        assert(self.code[-2] == ('addi', reg_num('sp'), reg_num('sp'), stack_size))
        # end with a ret
        assert(self.code[-1] == ('ret',))

        blocks = self.find_basic_blocks(3, -3)
        # print(f'blocks: {blocks}')

        stack_offset_to_i = lambda offset: (stack_size - 8 + offset)//4

        address_to_block = lambda address: [i for i,block in enumerate(blocks) if block[0] == address][0]

        for i,block in enumerate(blocks):
            print(f'# bblock {i}')
            reg_to_stack = {0: ['const', 0]}
            if i == 0:
                reg_to_stack[10] = ['arg', 0]
                reg_to_stack[11] = ['arg', 1]
            for address in block:
                inst = self.get_inst(address)
                # print(f'{address}: {inst}')
                if inst[0] == 'lw' and inst[2] == reg_num('s0'):
                    reg_to_stack[inst[1]] = ['local',stack_offset_to_i(inst[3])]
                elif inst[0] == 'lw':
                    reg_to_stack[inst[1]] = ['lw', reg_to_stack[inst[2]]]
                elif inst[0] == 'sw' and inst[2] == reg_num('s0'):
                    stack_i = (stack_size - 8 + inst[3]) // 4
                    print(f'local{stack_i} = {print_expr(reg_to_stack[inst[1]])}')
                elif inst[0] in {'slli', 'addi'}:
                    reg_to_stack[inst[1]] = [inst[0].rstrip('i'), reg_to_stack[inst[2]], ['const',inst[3]]]
                elif inst[0] in {'add'}:
                    reg_to_stack[inst[1]] = [inst[0], reg_to_stack[inst[2]], reg_to_stack[inst[3]]]
                elif inst[0] == 'mv':
                    reg_to_stack[inst[1]] = reg_to_stack[inst[2]]
                elif branches(inst[0]):
                    assert(address == block[-1])
                    if inst[0] == 'j':
                        print(f'jump to block {address_to_block(inst[1])}')
                    elif inst[0].startswith('b'):
                        print(f'if ({inst[0][1:]} {print_expr(reg_to_stack[inst[1]])} {print_expr(reg_to_stack[inst[2]])}) then block {address_to_block(inst[3])} else block {i+1}')
                    else:
                        raise ValueError(f'Unsupported branch {inst[0]}')
                else:
                    raise ValueError(f'Unsupported op {inst[0]}')
                # print(reg_to_stack)
            if i == len(blocks) - 1:
                print(f'return {print_expr(reg_to_stack[10])}')
