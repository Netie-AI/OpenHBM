# refresh_mgr

DRFM request shim with Misra-Gries PRAC (fixed $K = 64$ tables per bank),
per-bank credits, and sticky `drfm_pending` / target latches.

See `docs/rfcs/0002-refresh-policy.md` for the architectural decision record.

## Ports

| Signal | Dir | Width | Description |
| ------ | --- | ----- | ----------- |
| `clk_i`, `rst_ni` | in | 1 | Core clock / async active-low reset |
| `act_valid_i`, `act_{bg,ba,row}_i` | in | misc | Bank-machine activation event |
| `trefw_tick_i` | in | 1 | One-cycle pulse at each abstract `tREFW` boundary |
| `credit_release_i` | in | 1 | Scheduler returns a deferral credit |
| `drfm_pending_o` | out | 1 | Sticky indicator that DRFM service is required |
| `drfm_target_{bg,ba,row}_o` | out | packed | Hot row selected for DRFM scrub |
| `drfm_ack_i` | in | 1 | Downstream completed the DRFM handshake |
| `prac_overflow_alert_o` | out | 1 | PRAC pressure with exhausted credits |

## Wavedrom — defer / resume sequence

```wavedrom
{ "signal": [
  { "name": "clk", "wave": "p........." },
  { "name": "trefw", "wave": "010......." },
  { "name": "pending", "wave": "0.1...0.." },
  { "name": "drfm_ack", "wave": "0....10.." },
  { "name": "credits[b]", "wave": "42333....." }
],
  "head": { "text": "Sticky drfm_pending until ack; credit decrements on ack; tREFW tick refills" }
}
```

Credits return to `CreditMax` on each `tREFW` tick pulse. Between ticks, each
`drfm_ack` decrements the credit bucket for the latched bank unless the counter
was already zero.

## SymbiYosys

Run `sby -f fpv/refresh_liveness.sby` after editing RTL or wrappers. The bench
instantiates `refresh_mgr` with reduced `PracTopK`/`NumBanks` for convergence
but exercises the identical RTL implementation as simulation.
