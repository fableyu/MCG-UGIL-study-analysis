# Data dictionary

`1.HomeCe_RawData.xlsx` is the analysis input. Participant IDs retain leading zeros; the first two digits identify the centre.

## Worksheets

| Worksheet | Contents |
| --- | --- |
| `0.screening log` | Screening date, enrolment status, exclusion reason and enrolment ID. |
| `1baseline+satisfaction+followup` | Demographics, indication, self-administration, satisfaction, capsule excretion and examination timestamps. |
| `1.procedural steps` | Routine step completion derived from overall procedural status, water intake, posture and response to water guidance. |
| `1.Withdraw or excluded list` | Withdrawal or exclusion reasons and available participant characteristics. |
| `1.Adverse events` | Event type, severity, relationship, management and outcome. |
| `2.lesion record` | Lesion labels, manual and AI keyframe diagnoses, OGD diagnoses, concordance and clinical importance. |
| `3.reading time` | Paired manual and AI keyframe reading times. |
| `4.visualisation rates` | Visualisation of gastric anatomical landmarks. |
| `5.Examination time of MCG` | Oesophageal, gastric and small-intestinal examination durations. |

## Coding and units

- `Patient Source`: 1=outpatient clinic; 2=endoscopy centre.
- Comfort and convenience: 1=Excellent; 2=Good; 3=Poor.
- `Consistent`/`Inconsistent`: concordance with OGD.
- Clinical importance: `Clinically important UGIL` or `Others`.
- Landmark visualisation: 1=visualised; 0=not visualised.
- Reading times are in minutes; regional examination durations are in seconds. `na` denotes no recorded small-intestinal entry during recording.
- Capsule excretion time is in days. For unobserved expulsion confirmed by radiography, the estimate uses the last recorded bowel movement before radiography.
