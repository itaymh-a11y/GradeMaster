# Firestore Schema - Degree Templates

This document defines the shared template structure and snapshot import behavior.

## Collections

### `degreeTemplates/{templateId}`

Template metadata managed by admin only.

Fields:

- `degreeName` (`string`)
- `institutionName` (`string`)
- `cohortLabel` (`string`) - e.g. `2024`
- `degreeCreditsTarget` (`number`)
- `status` (`string`) - `draft | published | archived`
- `version` (`number`) - increment on content updates
- `createdByUid` (`string`)
- `createdAt` (`timestamp`)
- `updatedAt` (`timestamp`)

### `degreeTemplates/{templateId}/courses/{courseId}`

Template course payload (same shape as personal user course docs):

- `name` (`string`)
- `credits` (`number`)
- `isPassFail` (`bool`)
- `academicYear` (`string`) - `a|b|c|d`
- `semester` (`string`) - `a|b|summer`
- `finalBonus` (`number`)
- `moedBPolicy` (`string`) - `higher|moedB`
- `fastGrading` (`bool`) - quick single-grade mode
- `rootNode` (`map`) - grade tree map from `gradeNodeToMap`

### `users/{uid}`

Personal metadata. Snapshot apply writes:

- `degreeCreditsTarget` (`number`) - copied from selected template
- `appliedTemplate` (`map`)
  - `templateId` (`string`)
  - `templateDisplayName` (`string`)
  - `templateVersion` (`number`)
  - `mode` (`string`) - `merge|replace`
  - `appliedAt` (`timestamp`)

### `users/{uid}/courses/{courseId}`

Personal course docs, fully owned by user after import. Future template updates do not modify these docs.

## Snapshot Rules

1. `merge`: append copied template courses to existing user courses.
2. `replace`: delete existing user courses and then copy template courses.
3. In both modes, copied courses are new documents under `users/{uid}/courses`.
4. There is no live relation between imported user courses and template courses.
