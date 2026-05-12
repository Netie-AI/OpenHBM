// Copyright 2026 The Netie Open HBM Authors
// SPDX-License-Identifier: Apache-2.0
//
// Abstract nondeterministic bank-machine façade for bounded refresh proofs.
//
// In refresh_liveness.sby every primary input feeding refresh_mgr stays
// unconstrained except for fairness assumptions authored in refresh_liveness.sv.
// That matches the abstraction described in docs/rfcs/0002-refresh-policy.md —
// RTL must remain correct for any bounded activation envelope the scheduler emits.
//
// Keeping this companion file anchors the linkage between prose + formal stubs.
// No ports: it exists so reviewers can cite a named artefact in the ADR corpus.
module abs_bank_machine;
endmodule : abs_bank_machine
