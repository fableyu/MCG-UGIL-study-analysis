# Workbook data dictionary

The Excel workbook is the sole analysis input. Worksheet order and leading numeric prefixes are cosmetic; the labels below follow the current workbook. This dictionary describes the supplied schema; it does not contain participant records. Empty formatting rows are excluded using the sheet's ID column.

## Identifiers and populations

- Participant IDs (`Id`, `ID` or `id`) are five-character strings; retain leading zeros. The first two characters identify the study centre.
- Screening numbers use `S` followed by five digits. An enrolled screening record also has an `Enrolment ID`.
- Enrolled population: 482. Safety analysis set (SAS): 481 who swallowed the capsule. Full analysis set (FAS): 475 with paired evaluable examinations. Duodenal PPS: 420 with recorded duodenal entry.
- Repeated IDs in the lesion worksheet represent separate lesion records. All other participant-level sheets use one record per participant, except the event table, which lists recorded events.

## Screening log

`0.screening log` contains 906 records. Fields are `Screening number`, `Date`, `Enrolled (Yes/No)`, `Reason for exclusion`, and `Enrolment ID`. The date is retained as supplied. Chronology discrepancies with examination dates are reported separately; no screening dates are inferred or replaced.

## Baseline and follow-up

`1baseline+satisfaction+followup` contains 475 FAS records.

- `Age`: years. `Gender`: Female/Male.
- `Indication`: one of the six source labels; symptom labels are collapsed only for the indication-group summary.
- `Patient Source`: 1=outpatient clinic; 2=endoscopy unit.
- `Self-administered Results`: normal independent completion, a water-intake deviation, a postural deviation, or their combination.
- `Capsule Elimination Time`: recorded days. In two source notes, natural expulsion was not observed and the recorded day represents last defecation before radiographic confirmation. Preserve these records and their notes.
- Comfort and operational convenience: 1=Excellent; 2=Good; 3=Poor.
- `Observed excretion time category`: derived from recorded days and the unobserved-expulsion note. Script 04 recalculates the category and checks it against the source column.
- `MCG examination time` and the legacy header `EGD examination time`: paired timestamps. The latter refers to OGD as named in the article. Elapsed time is calculated in minutes. The supplied timestamps are not shifted or replaced.

## Withdrawals and events

`1.Withdraw or excluded list` contains seven records with exclusion reason and available baseline fields. One participant could not swallow the capsule and is excluded from the SAS; all seven are excluded from the FAS.

`1.Adverse events` contains the recorded adverse events and device failure. Fields describe event type, relationship, severity, indication, onset, duration, management and outcome. Safety percentages use the SAS denominator.

## Lesions

`2.lesion record` contains 798 records across 475 participants. Fields are `ID`, within-participant `Lesion` label, `Manual_Result`, `Manual vs OGD`, `OGD_Result`, `OGD vs AI`, `AI_keyframe_reading_Result`, and `Binary classification in subgroup analysis`.

`Consistent`/`Inconsistent` are adjudicated concordance labels. The clinically important classification is read from the source workbook. Six records lack a within-participant lesion label but have complete diagnostic fields; the supplied analysis retains them. Lesion size and oesophagitis grade are not separate fields in this workbook.

## Reading, visualisation and examination time

- `3.reading time`: paired manual and AI keyframe reading times in minutes, with headers `manual reading (min)` and `AI keyframe reading (min)`; headers without `(min)` are also accepted.
- `4.visualisation rates`: six gastric landmarks coded 1=visualised and 0=not visualised.
- `5.Examination time of MCG`: oesophageal, gastric and small-intestinal durations in seconds. Script 04 converts seconds to minutes. The literal `na` in 55 small-intestinal records denotes no recorded entry within the effective recording period; it is not a zero duration.

## Derived procedural steps

The optional `1.procedural steps` sheet is a derived view of `Self-administered Results`. Under the author-confirmed rule, known source statuses identify only water/posture deviations; other routine steps are classified as completed. The sheet preserves source IDs and the source status alongside the derived columns. It must not be represented as a separate set of directly observed step logs.

`Response to water guidance` uses `No deviation recorded`. The source does not establish whether an AI prompt was actually issued, so prompt-issued and no-prompt counts are not inferred.
