## Creating the Zoomable Sunburst Diagrams

 1. Generate the provenance score.
 2. Translate the YAML output to the D3 JSON using the script.
  `../../../translate_scoretree_for_d3.pl`
 3. Remove the outside `[]` from the produced JSON.
 4. Create a copy of the zoomable_sunburst.
 5. Update line 45 to point to your new JSON file.
