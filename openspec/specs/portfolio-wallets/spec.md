# Delta for Portfolio Wallet Breakdown

## ADDED Requirements

### Requirement: Wallet breakdown grid is available

The portfolio detail screen MUST display the existing wallet breakdown as a
two-column grid, with one wallet card for each wallet in the selected portfolio.
Each card MUST show the wallet name, USD total, cryptocurrency list, and
balances.

#### Scenario: Portfolio with multiple wallets

- GIVEN a selected portfolio contains multiple wallets
- WHEN the user opens the portfolio detail screen
- THEN the screen displays one wallet card per wallet in a two-column grid
- AND each card shows its wallet name, USD total, cryptocurrencies, and balances

#### Scenario: Portfolio with no wallets

- GIVEN a selected portfolio contains no wallets
- WHEN the user opens the portfolio detail screen
- THEN no wallet cards are displayed
- AND the screen remains usable without a rendering error

### Requirement: Wallet card navigation and actions remain connected

Each wallet card MUST preserve the existing navigation and movement actions.
The wallet header MUST open the wallet movements view, and the add action MUST
offer the supported movement creation forms.

#### Scenario: Open wallet movements

- GIVEN the wallet breakdown grid displays a wallet card
- WHEN the user taps the wallet header
- THEN the wallet movements view opens for that wallet

#### Scenario: Create a movement from a wallet card

- GIVEN the wallet breakdown grid displays a wallet card
- WHEN the user opens its add menu
- THEN the menu provides entry, exit, transfer, and swap movement forms

#### Scenario: Build the reconnected screen

- GIVEN the portfolio detail screen includes the wallet breakdown grid
- WHEN the macOS target is built
- THEN the target builds without errors