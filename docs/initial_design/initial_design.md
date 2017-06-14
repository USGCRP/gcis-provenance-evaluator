## Needs

A better way of judging how successful GCIS is in providing provenance to the HISA products USGCRP produces and other primary publications stored in GCIS.  
Previous evaluation was based on the quantity of resources linked into GCIS. Instead, we are seeking to evaluate GCIS by how well those items preserve the provenance of the primary publications.

## Provenance Rating

[whiteboard](./ratings.jpg)

A 5 point system:

  - very poor:  provenance is broken, no way to find the resource outside of GCIS.
    - example: a Person with first & last name, but no URL or OrcID.
  - poor:       provenance is weak. Expert users may be able to reconstruct the provenance with the existing data.
    - example: a Book with Title and Year, but no publisher or ISBN.
  - acceptable: provenance is preserved
    - example: a figure with its Report, title, and ordinal.
  - good:       provenance is enhanced. Access to external provenance infomation is readily available. External links provided. Target rating.
    - example: a figure with Report, title, ordinal, caption, & source citation.
  - very good:  provenance is enhanced & extra non-provenance information is provided.
    - Journal with url, print ISSN, title, publisher, and country, notes.

## Publication Ratings

[whiteboard](./triple_score_breakdown.jpg)

### Internal Score

  - a score for all fields stored directly on a Resource
    - includes items stored in helper tables (country, etc), but not in full component scores (figure, table, etc), which belong below.

### Connection Score

  - Contributors are scored
  - References are scored

### Component Score

  - each component of the publication gets scored
    - e.g. a report may have chapters, figures, etc.

## Robust Resources

[![Robust Contributor][./robust-contributor.jpg]]
[![Robust Component][./robust-component.jpg]]
[![Robust Publication][./robust-publication.jpg]]
[![Robust Reference][./robust-reference.jpg]]

## Program Design

### Steps

The evaluation is design in three steps.  
First, each resource has the 5 point score determined for each of its scores. This is saved as a yaml file. Format TBD.  
Secondly, this script will take a GCIS Publication URI and evaluate it based on the yaml breakdown. It will generate a tree format to hold the values.  
Finally, any nunber of scripts can be written to display or parse the evaluation. Initial thoughts are roll-up scoring that averages the scores to a certain depth, isolating all '1' ratings to focus work, or all '0' ratings to focus trimming.

**Whiteboards**:  
[Step 1 - generate ratings](./Step 1 - generate ratings.jpg)  
Step 2 - tree-generate [1](./Step 2 - tree-generate-1.jpg) [2](./Step 2 - tree-generate-2.jpg)  
[Step 3 - display-data](./Step 3 - display-data.jpg)  
[Step 3 mockup](display-data-mockup.jpg)  


