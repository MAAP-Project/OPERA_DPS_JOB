cwlVersion: v1.2
$graph:
- class: Workflow
  label: operawatermask1
  doc: None
  id: operawatermask1
  inputs:
    SHORT_NAME:
      doc: SHORT_NAME
      label: SHORT_NAME
      type: string
    TEMPORAL:
      doc: TEMPORAL
      label: TEMPORAL
      type: string
    IDX_WINDOW:
      doc: IDX_WINDOW
      label: IDX_WINDOW
      type: string
  outputs:
    out:
      type: Directory
      outputSource: process/outputs_result
  steps:
    process:
      run: '#main'
      in:
        SHORT_NAME: SHORT_NAME
        TEMPORAL: TEMPORAL
        IDX_WINDOW: IDX_WINDOW
      out:
      - outputs_result
- class: CommandLineTool
  id: main
  requirements:
    DockerRequirement:
      dockerPull: ghcr.io/maap-project/opera_dps_job:ogc
    NetworkAccess:
      networkAccess: true
    ResourceRequirement:
      ramMin: 10
      coresMin: 1
      outdirMax: 20
  baseCommand: /OPERA_DPS_JOB/run.sh
  inputs:
    SHORT_NAME:
      type: string
      inputBinding:
        position: 1
        prefix: --SHORT_NAME
    TEMPORAL:
      type: string
      inputBinding:
        position: 2
        prefix: --TEMPORAL
    IDX_WINDOW:
      type: string
      inputBinding:
        position: 3
        prefix: --IDX_WINDOW
  outputs:
    outputs_result:
      outputBinding:
        glob: ./output*
      type: Directory
s:author:
- class: s:Person
  s:name: OPERA
s:contributor:
- class: s:Person
  s:name: None
s:citation: null
s:codeRepository: https://github.com/MAAP-Project/OPERA_DPS_JOB.git
s:commitHash: 4c57e282e9d891180c49177810b471281cf47e2e
s:dateCreated: 2026-07-09
s:license: https://github.com/MAAP-Project/OPERA_DPS_JOB/blob/ogc/LICENSE
s:softwareVersion: 1.0.0
s:version: ogc
s:releaseNotes: None
s:keywords: null
$namespaces:
  s: https://schema.org/
$schemas:
- https://raw.githubusercontent.com/schemaorg/schemaorg/refs/heads/main/data/releases/9.0/schemaorg-current-http.rdf
