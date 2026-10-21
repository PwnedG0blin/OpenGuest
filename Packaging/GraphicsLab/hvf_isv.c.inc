/* Pinned QEMU bridge: preserve all architectural state on emulation failure. */
static bool stratovo_hvf_access(void *opaque, uint64_t va, uint8_t *data,
                                unsigned size, bool write)
{
    return cpu_memory_rw_debug(opaque, va, data, size, write) == 0;
}
static bool stratovo_hvf_isv(CPUState *cpu, bool write)
{
    CPUARMState *env = &ARM_CPU(cpu)->env;
    StratovoArmMemoryState state;
    uint32_t insn;
    cpu_synchronize_state(cpu);
    if (cpu_memory_rw_debug(cpu, env->pc, (uint8_t *)&insn, 4, false)) { return false; }
    memcpy(state.x, env->xregs, sizeof(state.x));
    for (int i = 0; i < 32; i++) { memcpy(state.q[i], &env->vfp.zregs[i], 16); }
    if (!stratovo_arm_memory(&state, le32_to_cpu(insn), write, stratovo_hvf_access, cpu)) {
        error_report("Stratovo HVF: unsupported ISV=0 instruction 0x%08x at pc=0x%" PRIx64,
                     le32_to_cpu(insn), (uint64_t)env->pc);
        return false;
    }
    memcpy(env->xregs, state.x, sizeof(state.x));
    for (int i = 0; i < 32; i++) { memcpy(&env->vfp.zregs[i], state.q[i], 16); }
    cpu->accel->dirty = true;
    return true;
}
