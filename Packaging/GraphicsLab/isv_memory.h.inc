/* AArch64 ISV=0 memory operations for the pinned HVF adapter.
 * GPL-2.0-or-later. Instruction classes follow Arm's A64 encodings and
 * Lucas Amaral's QEMU ISV=0 emulation proposal (2026-03-09).
 * Never advance an unknown instruction, or silently ignore a failed access.
 */
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

typedef struct StratovoArmMemoryState {
    uint64_t x[32]; /* x[31] is SP only for an address base. */
    uint8_t q[32][16];
} StratovoArmMemoryState;
typedef bool (*StratovoArmAccess)(void *, uint64_t, uint8_t *, unsigned, bool);

static int64_t stratovo_sign(uint64_t value, unsigned bits)
{
    return (int64_t)(value << (64 - bits)) >> (64 - bits);
}
static uint64_t stratovo_arm_get(const StratovoArmMemoryState *s, unsigned reg)
{
    return reg == 31 ? 0 : s->x[reg];
}
static void stratovo_arm_put(StratovoArmMemoryState *s, unsigned reg, uint64_t value)
{
    if (reg != 31) { s->x[reg] = value; }
}
static bool stratovo_arm_memory(StratovoArmMemoryState *s, uint32_t insn,
                                bool write, StratovoArmAccess access, void *opaque)
{
    unsigned rt = insn & 31, rn = (insn >> 5) & 31;
    unsigned rt2 = (insn >> 10) & 31, n = 0, count = 1;
    bool vec = (insn >> 26) & 1, load = false, wb = false;
    unsigned signbits = 0;
    uint64_t base = s->x[rn], address = base;
    int64_t offset = 0;

    if ((insn & 0x3a000000u) == 0x28000000u) {
        unsigned opc = insn >> 30, mode = (insn >> 23) & 3;
        load = (insn >> 22) & 1;
        if (opc == 3 || (!vec && opc == 1 && (!load || mode == 0))) { return false; }
        n = vec ? (4u << opc) : (opc == 2 ? 8 : 4);
        signbits = (!vec && opc == 1) ? 64 : 0;
        count = 2;
        offset = stratovo_sign((insn >> 15) & 127, 7) * n;
        wb = mode == 1 || mode == 3;
        address = mode == 1 ? base : base + offset;
        if (load && rt == rt2) { return false; }
        if (wb && !vec && rn != 31 && (rn == rt || rn == rt2)) { return false; }
    } else if ((insn & 0x3a000000u) == 0x38000000u) {
        unsigned size = insn >> 30, opc = (insn >> 22) & 3;
        bool scaled = (insn >> 24) & 1, regoffset = !scaled && ((insn >> 21) & 1);
        unsigned mode = (insn >> 10) & 3;
        if (vec) {
            if (opc >= 2 && size != 0) { return false; }
            n = opc >= 2 ? 16 : 1u << size;
            load = opc & 1;
        } else {
            n = 1u << size;
            if ((size == 3 && opc >= 2) || (size == 2 && opc == 3)) { return false; }
            load = opc != 0;
            signbits = opc == 2 ? 64 : opc == 3 ? 32 : 0;
        }
        if (scaled) {
            offset = ((insn >> 10) & 4095) * n;
        } else if (regoffset) {
            unsigned option = (insn >> 13) & 7, rm = (insn >> 16) & 31;
            uint64_t index = stratovo_arm_get(s, rm);
            if (mode != 2 || !(option & 2)) { return false; } /* Reject atomic encodings. */
            if (option == 2) { index = (uint32_t)index; }
            if (option == 6) { index = (int64_t)(int32_t)index; }
            if ((insn >> 12) & 1) { index *= n; }
            offset = (int64_t)index;
        } else {
            if (mode == 2) { return false; } /* Unprivileged forms require different translation. */
            offset = stratovo_sign((insn >> 12) & 511, 9);
            wb = mode == 1 || mode == 3;
            if (wb && !vec && rn != 31 && rn == rt) { return false; }
        }
        address = (!scaled && !regoffset && mode == 1) ? base : base + offset;
    } else {
        return false;
    }
    if (load == write) { return false; }
    uint8_t bytes[32] = {0};
    for (unsigned i = 0; i < count && write; i++) {
        unsigned r = i ? rt2 : rt;
        if (vec) { memcpy(bytes + i * n, s->q[r], n); }
        else {
            uint64_t value = stratovo_arm_get(s, r);
            for (unsigned j = 0; j < n; j++) { bytes[i*n+j] = value >> (j*8); }
        }
    }
    /* Use the decoded virtual address, including page-straddling pairs.
     * The fault IPA can refer to the second page and is not the access start. */
    if (!access(opaque, address, bytes, count * n, write)) { return false; }
    if (load) {
        for (unsigned i = 0; i < count; i++) {
            unsigned r = i ? rt2 : rt;
            if (vec) { memset(s->q[r], 0, 16); memcpy(s->q[r], bytes + i*n, n); }
            else {
                uint64_t value = 0;
                for (unsigned j = 0; j < n; j++) { value |= (uint64_t)bytes[i*n+j] << (j*8); }
                if (signbits) { value = stratovo_sign(value, n*8); }
                if (signbits == 32) { value = (uint32_t)value; }
                stratovo_arm_put(s, r, value);
            }
        }
    }
    if (wb) { s->x[rn] = base + offset; }
    return true;
}
