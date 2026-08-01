# Portfolio KPI Normalization Specification

## Purpose

Define portfolio summary KPIs in a single comparable currency. All investment,
current value, gain, and return metrics SHALL be calculated and displayed in
USD, regardless of the fiat currency used on individual movements.

## Requirements

### Requirement: Calculate portfolio KPIs in USD only

The system MUST calculate investment, current value, gain, and return KPIs from
USD-valued movement and asset data. Alternate fiat amounts MUST NOT be added to
or substituted for USD amounts in portfolio, wallet, or crypto summaries.

#### Scenario: Portfolio contains movements in multiple alternate fiats

- GIVEN movements use USD, EUR, and MXN as alternate fiats
- WHEN portfolio KPIs are calculated
- THEN every KPI is based only on the corresponding USD values
- AND the result is independent of which alternate fiats are present

#### Scenario: Portfolio contains no alternate fiat values

- GIVEN all movements have USD values and no alternate fiat values
- WHEN portfolio KPIs are calculated
- THEN the USD totals and percentages are calculated without missing-value errors

### Requirement: Do not select an arbitrary fiat currency

The system MUST NOT use an arbitrary alternate fiat, including the first fiat
returned by a collection, as the currency for aggregating or formatting KPI
values. KPI calculations and summary display values SHALL use their USD
counterparts explicitly.

#### Scenario: Alternate fiat collection order changes

- GIVEN the same portfolio data is returned with alternate fiats in a different order
- WHEN summary KPIs are calculated or displayed
- THEN the KPI values remain unchanged and are formatted as USD

#### Scenario: Alternate fiat has a different exchange rate

- GIVEN a movement has an alternate fiat amount whose value differs from its USD amount
- WHEN the movement contributes to a summary KPI
- THEN only its USD value contributes to the KPI
- AND no alternate-fiat exchange rate is selected implicitly

### Requirement: Calculate gain and return consistently in USD

The system MUST calculate gain as current USD value minus invested USD value.
Return percentage MUST be calculated from those USD values using invested USD as
the denominator. If invested USD is zero, the system MUST avoid division by zero
and return the defined neutral or unavailable state without using alternate fiat
values as a fallback.

#### Scenario: Portfolio has invested USD and current USD value

- GIVEN invested USD is 1,000 and current USD value is 1,250
- WHEN gain and return are calculated
- THEN gain is 250 USD
- AND return is 25 percent

#### Scenario: Mixed-fiat transaction produces a loss

- GIVEN transactions use EUR or MXN alternates and their USD totals are invested USD 2,000 and current USD 1,800
- WHEN gain and return are calculated
- THEN gain is -200 USD
- AND return is -10 percent

#### Scenario: Invested USD is zero

- GIVEN invested USD is zero
- WHEN return is calculated
- THEN the result is zero or unavailable according to the summary contract
- AND no alternate fiat amount is used as the denominator
