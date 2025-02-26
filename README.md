# Consensus Protocol

A Clarity smart contract that facilitates expert evaluation of academic manuscripts and compensates evaluators.

## Overview

The Consensus Protocol is a decentralized peer review system for academic manuscripts. It allows scholars to submit their work for review, enables qualified experts to provide evaluations, and ensures fair compensation for contributions to the academic ecosystem.

## Features

- **Manuscript Submission**: Scholars can submit manuscripts with IPFS hash references
- **Evaluator Registration**: Academic experts can register as evaluators by staking collateral
- **Evaluation Process**: Registered evaluators can review manuscripts and receive compensation
- **Dispute Resolution**: Allows for disputing potentially biased or low-quality evaluations
- **Reputation System**: Tracks evaluator credibility based on their participation
- **Administrative Controls**: Protocol settings can be adjusted by authorized administrators

## Contract Details

### Key Data Structures

- **Manuscripts**: Stores manuscript metadata, evaluation statistics, and status
- **Evaluations**: Records individual evaluations including ratings and comments
- **Evaluators**: Maintains evaluator profile data including collateral, evaluation count, and status

### Public Functions

#### For Scholars

- `submit-manuscript`: Submit a new manuscript with an IPFS hash reference
- `update-manuscript-status`: Update the status of a manuscript (pending, evaluated, rejected, accepted)

#### For Evaluators

- `register-evaluator`: Register as an evaluator by providing collateral
- `submit-evaluation`: Evaluate a manuscript with rating and comments
- `withdraw-collateral`: Withdraw staked collateral (for paused or inactive evaluators)
- `dispute-evaluation`: Dispute another evaluator's assessment

#### Administrative Functions

- `update-protocol-settings`: Update protocol parameters (collateral, honorarium)
- `pause-evaluator`: Pause an evaluator's ability to provide evaluations

### Read-Only Functions

- `get-manuscript-details`: Retrieve details about a specific manuscript
- `get-evaluation-details`: Get an evaluator's assessment of a manuscript
- `get-evaluator-details`: View an evaluator's profile information
- `get-evaluator-earnings`: Calculate an evaluator's total earnings

## Error Codes

- **100**: Not authorized
- **101**: Manuscript not found
- **102**: Already evaluated
- **103**: Invalid rating
- **104**: Insufficient balance
- **105**: Not an evaluator
- **106**: Manuscript already exists
- **107**: Empty hash
- **108**: Invalid ID
- **109**: Empty reason
- **110**: Self dispute
- **111**: Empty status
- **112**: Invalid status
- **113**: Already registered
- **114**: Invalid collateral
- **115**: Invalid honorarium
- **116**: Invalid evaluator

## Usage Example

```clarity
;; Submit a manuscript
(contract-call? .consensus-protocol submit-manuscript "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxM" u1)

;; Register as an evaluator
(contract-call? .consensus-protocol register-evaluator)

;; Evaluate a manuscript
(contract-call? .consensus-protocol submit-evaluation u1 u85 "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
```

## Security Considerations

- All input parameters are validated to prevent potential exploits
- Authorization checks are implemented for critical functions
- Proper error handling with descriptive error codes
- Token transfers are secured with try! expressions

## Development

### Prerequisites

- [Clarity](https://clarity-lang.org/) knowledge
- [Stacks blockchain](https://www.stacks.co/) development environment

### Deployment

1. Deploy the contract to the Stacks blockchain
2. Set appropriate initial values for collateral and honorarium
3. Register evaluators and begin manuscript submissions

