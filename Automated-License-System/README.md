# AI Model Licensing Marketplace

A decentralized platform enabling AI model creators to publish, license, and monetize their models through blockchain-based smart contracts with automated payments and transparent revenue distribution.

## Overview

This smart contract provides a comprehensive marketplace for AI models where creators can register their models, set pricing and licensing terms, and users can purchase time-limited licenses. The platform handles automated payment distribution, revenue tracking, and license management.

## Key Features

- Model registration with comprehensive metadata
- Time-based licensing system
- Automated payment splitting between creators and platform
- License transfer capabilities
- Revenue tracking and analytics
- Administrative controls for marketplace management
- Batch license verification

## Contract Constants

### Commission Configuration
- Default commission rate: 2.5% (250 basis points)
- Maximum commission rate: 10% (1000 basis points)
- Commission basis points: 10,000

### License Duration Limits
- Minimum duration: 144 blocks
- Maximum duration: 52,560 blocks

### Pricing and Technical Constraints
- Minimum license price: 1,000 microSTX
- Maximum file size: 1,000,000,000 bytes
- Maximum accuracy score: 10,000
- License transfer fee: 50,000 microSTX

## Data Structures

### AI Models Map
Stores core model information including creator, title, description, pricing, duration, activation status, registration time, and total sales.

### Licenses Map
Tracks license ownership with expiration dates, purchase timestamps, amounts paid, and activation status.

### Model Specs Map
Contains technical metadata including version, file hash, file size, and accuracy metrics.

### Model Earnings Map
Financial analytics tracking total revenue, active licenses, and accumulated platform fees.

## Public Functions

### Model Management

#### register-model
Registers a new AI model in the marketplace.

Parameters:
- title (string-ascii 64): Model name
- description (string-ascii 256): Model description
- price (uint): License price in microSTX
- duration (uint): License duration in blocks
- version (string-ascii 16): Model version
- file-hash (string-ascii 64): File hash for verification
- file-size (uint): File size in bytes
- accuracy (uint): Accuracy score (0-10000)

Returns: Model ID

#### update-model
Updates model metadata. Only callable by model creator.

Parameters:
- model-id (uint): Target model ID
- title (string-ascii 64): Updated title
- description (string-ascii 256): Updated description
- price (uint): Updated price

#### toggle-model
Toggles model availability status. Only callable by model creator.

Parameters:
- model-id (uint): Target model ID

Returns: New activation status

### License Operations

#### buy-license
Purchases a new license for a model.

Parameters:
- model-id (uint): Target model ID

Returns: License expiration block height

Restrictions:
- User cannot already have a valid license
- User cannot be the model creator
- Model must be active
- Marketplace must be operational

#### renew-license
Renews an existing license.

Parameters:
- model-id (uint): Target model ID

Returns: New expiration block height

#### transfer-license
Transfers license ownership to another user.

Parameters:
- model-id (uint): Target model ID
- new-holder (principal): Recipient address

Fees: 50,000 microSTX transfer fee

### Analytics and Verification

#### batch-check-licenses
Verifies licenses for multiple models in a single call.

Parameters:
- model-ids (list 5 uint): List of model IDs to check

Returns: List of verification results

### Administrative Functions

#### set-commission
Updates the platform commission rate. Admin only.

Parameters:
- new-rate (uint): New commission rate in basis points

#### toggle-marketplace
Toggles marketplace operational status. Admin only.

#### disable-model
Administratively disables a model. Admin only.

Parameters:
- model-id (uint): Target model ID

#### withdraw
Emergency withdrawal of contract balance. Admin only.

Parameters:
- amount (uint): Amount to withdraw in microSTX

## Read-Only Functions

### get-model
Retrieves complete model information.

### get-license
Retrieves license details for a specific user and model.

### get-specs
Retrieves technical specifications for a model.

### get-earnings
Retrieves financial metrics for a model.

### has-valid-license
Checks if a user has a valid active license.

### calculate-commission
Calculates platform commission for a given amount.

### get-stats
Retrieves comprehensive marketplace statistics including total models, volume, commission rate, and operational status.

### get-model-analytics
Provides comprehensive analytics combining model information, financial data, technical specifications, and average revenue per sale.

### check-access
Verifies user access permissions for a model, including license status and creator privileges.

## Error Codes

- ERR-UNAUTHORIZED-ACCESS (100): Insufficient permissions
- ERR-RESOURCE-NOT-FOUND (101): Requested resource does not exist
- ERR-DUPLICATE-RESOURCE (102): Resource already exists
- ERR-INSUFFICIENT-PAYMENT (103): Payment amount insufficient
- ERR-LICENSE-EXPIRED (104): License has expired or is inactive
- ERR-ACCESS-DENIED (105): Access denied for operation
- ERR-INVALID-PARAMETERS (106): Invalid input parameters
- ERR-SERVICE-UNAVAILABLE (107): Service temporarily unavailable
- ERR-PAYMENT-TRANSFER-FAILED (108): Payment transfer operation failed

## Payment Flow

1. User initiates license purchase
2. Contract calculates platform commission
3. Creator receives (price - commission)
4. Platform receives commission
5. License is created with expiration date
6. Revenue tracking is updated

## Security Considerations

- Only contract owner has administrative privileges
- Model creators can only modify their own models
- License transfers require active, non-expired licenses
- All payment transfers are atomic operations
- Marketplace can be paused for emergency maintenance

## Usage Example

### Registering a Model
```clarity
(contract-call? .ai-marketplace register-model
  "GPT-Style Model"
  "Advanced language model for text generation"
  u5000000
  u1440
  "v1.0.0"
  "abc123...def456"
  u50000000
  u9500)
```

### Purchasing a License
```clarity
(contract-call? .ai-marketplace buy-license u1)
```

### Checking License Status
```clarity
(contract-call? .ai-marketplace has-valid-license u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Development and Deployment

This contract is written in Clarity for the Stacks blockchain. Deploy using the Stacks CLI or compatible development tools.