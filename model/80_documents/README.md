<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# Engineering document sources

`Documents.sysml` selects authoritative model content using the shared `Elan8::Documents` vocabulary. `prose/`, `figures/`
and `template/` contain authored publication inputs. Paths in document metadata are relative to this directory. The four
documents are the customer requirements specification (`PrinterDocuments::crs`), the system requirements specification
(`srs`), the system design specification (`sds`) and the verification report (`vvr`).

Two prose files and the plots of the verification report are **generated and committed**, so that the documents build without
a simulator:

| File | Written by | Run again when |
| --- | --- | --- |
| `prose/sds-trade-study.md` (and `docs/trade-study.md`) | `python3 scripts/trade_study.py --write` | a design value, a limit or a candidate changes |
| `prose/vvr-results.md`, `figures/axis-*.svg` (the plots) | `python3 scripts/write_verification_report.py` after `scripts/verify_axis.sh` | the firmware, the plant or the model changes |

`figures/axis-plant.svg` is an authored drawing and is not checked against the model.

## Build

[Doc42](https://github.com/elan8/doc42-release) renders the documents as PDF with the house template in `template/`.
`doc42 list model` and `doc42 check model` need no account. To build, create an API token and set it as `ELAN8_TOKEN`:

```sh
doc42 check model --workspace-root .
doc42 build model --workspace-root . --doc PrinterDocuments::sds --out generated/documents
```

Rendered PDFs go to `generated/documents/`; never commit them. CI builds all four on every run.

Doc42 0.8.1 embeds version 0.8.0 of the Elan8 domain library, which does not have the stepper motor that
`model/70_verification/AxisPlant.sysml` uses, so `doc42 check` reports unresolved references in that file, as warnings. They
disappear when Doc42 embeds a newer domain library. The documents do not read the plant.
