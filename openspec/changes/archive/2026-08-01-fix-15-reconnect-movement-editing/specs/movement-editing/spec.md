# Movement Editing Specification

## Purpose

Define the movement-editing behavior available from portfolio and crypto detail views.

## Requirements

### Requirement: Detail views provide movement editing

The system MUST allow a user to open the movement editor from a movement row in `CarteraCryptoDetailView`, `CarteraMovimientosView`, and `CryptoDetailViews`.

#### Scenario: Open the editor from any supported detail view

- GIVEN a detail view displays a movement row
- WHEN the user selects the row
- THEN the system MUST present the movement editor with that movement selected

#### Scenario: The editor is available after reconnecting the detail-view flow

- GIVEN the application has loaded its model context
- WHEN the user selects a movement in any of the three detail views
- THEN the editor MUST open without requiring a pre-built editing view model or an external edit-mode value

### Requirement: The editor loads the selected movement correctly

The movement editor MUST derive the appropriate editing mode from the selected movement and MUST load all data required to edit Entrada, Salida, EntreCarteras, and Swap movements.

#### Scenario: Load each supported movement type

- GIVEN a selected movement of type Entrada, Salida, EntreCarteras, or Swap
- WHEN the editor is presented
- THEN the form MUST display the selected movement's existing values and the controls for its type

#### Scenario: Preserve movement type during editing

- GIVEN the editor is presented for a selected movement
- WHEN the user reviews or changes editable values
- THEN the editor MUST continue using the selected movement's derived edit mode

### Requirement: Saving an edit refreshes the originating detail view

The system MUST save valid movement edits through the shared model context, dismiss the editor after a successful save, and refresh the originating movement list.

#### Scenario: Save a valid edit

- GIVEN the user has changed valid values in the movement editor
- WHEN the user saves
- THEN the movement MUST be updated, the editor MUST dismiss, and the originating list MUST show the saved values

#### Scenario: Cancel without saving

- GIVEN the editor is displaying an existing movement
- WHEN the user dismisses the editor without saving
- THEN the movement MUST remain unchanged and the originating list MUST remain consistent
