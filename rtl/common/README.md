# rtl/common

Shared definitions and hand-instantiated primitives.

| file | contents |
|---|---|
| uop_defs.svh | bit indices of the one-hot uop vectors |
| cc_pmux.sv | 1-bit priority mux on a CCU2C carry chain |
| dup_reg.sv | register copy for fanout splitting |
| dup_reg_clear.sv | register copy with per-bit synchronous clear through set/reset |
| iq_rowcell.sv | IQ row next state, LUT4 + PFUMX per output |
| iq_grantcell.sv | IQ grant destinations, one LUT4 each |
| ecp5_models.v | LUT4, PFUMX, L6MUX21, CCU2C behaviour for simulation and formal only |
