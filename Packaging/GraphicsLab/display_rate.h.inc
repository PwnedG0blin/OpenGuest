/* Advertised guest refresh rate. Zero preserves the physical display rate. */
static int stratovo_refresh_hz(const char *value)
{
    if (!value) { return 0; }
    const char *rates[] = {"30", "60", "90", "120", "144", "165", "240"};
    for (unsigned i = 0; i < sizeof(rates) / sizeof(rates[0]); i++) {
        if (!strcmp(value, rates[i])) { return atoi(value); }
    }
    return 0;
}
