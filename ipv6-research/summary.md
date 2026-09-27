# IPv6 audit summary — 600 hosts

Generated: 2026-09-27T10:32:43+00:00

## Verdicts

| Verdict | Count | % |
|---|---:|---:|
| no_aaaa | 492 | 82.0% |
| aaaa_ok | 82 | 13.7% |
| domain_dead | 16 | 2.7% |
| aaaa_tcp_fail | 10 | 1.7% |

**With AAAA:** 92/600 (15.3%)  |  **AAAA fully working:** 82/92 (89.1%) of those

## By group

| Group | Hosts | With AAAA | AAAA works | % AAAA | % works (of AAAA) |
|---|---:|---:|---:|---:|---:|
| gov.lk | 329 | 11 | 10 | 3.3% | 90.9% |
| ac.lk | 52 | 16 | 9 | 30.8% | 56.2% |
| university | 26 | 6 | 5 | 23.1% | 83.3% |
| other.lk | 164 | 49 | 48 | 29.9% | 98.0% |
| non-lk | 29 | 10 | 10 | 34.5% | 100.0% |

## Dead domains (NXDOMAIN)

Total: 16 — of which 1 have a live apex (only `www.` missing)

- `dambasncoe.sch.lk`
- `mncoe.sch.lk`
- `nncoe.sch.lk`
- `siyanencoe.sch.lk`
- `www.ancoe.sch.lk`
- `www.ayurvedicmedicoun.gov.lk`
- `www.bbu.ac.lk`
- `www.delimitation.gov.lk`
- `www.icta.lk`
- `www.itsuniversity.lk`
- `www.mgncoe.sch.lk`
- `www.nproccom.gov.lk`
- `www.sema.gov.lk`
- `www.skillsdevelop.lk`
- `www.slmti.lk`
- `www.sltc.lk` — apex `sltc.lk` resolves (A: 3.134.11.201, AAAA: none)

## AAAA present but broken

- **IPv6-only breakage** (IPv4 works): **9** — these are the real IPv6 failures
- **Site down entirely** (IPv4 also unreachable): 1

| Host | Verdict | IPv4 | Detail |
|---|---|---|---|
| uom.lk | aaaa_tcp_fail | up | timed out |
| www.ac.lk | aaaa_tcp_fail | up | [Errno 111] Connection refused |
| www.accimt.ac.lk | aaaa_tcp_fail | up | timed out |
| www.mrt.ac.lk | aaaa_tcp_fail | up | timed out |
| www.ruh.ac.lk | aaaa_tcp_fail | up | timed out |
| www.seu.ac.lk | aaaa_tcp_fail | up | timed out |
| www.svias.esn.ac.lk | aaaa_tcp_fail | up | timed out |
| www.uwu.ac.lk | aaaa_tcp_fail | up | timed out |
| www.vpa.ac.lk | aaaa_tcp_fail | up | timed out |
| www.fcd.gov.lk | aaaa_tcp_fail | down | timed out |

