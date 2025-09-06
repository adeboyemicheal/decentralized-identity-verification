# Decentralized Identity Verification System

A blockchain-based identity verification system built on Stacks using Clarity smart contracts. This system enables secure, decentralized identity management with oracle-based verification mechanisms.

## Overview

This project implements a decentralized identity verification system consisting of two main smart contracts:

1. **Identity Registry Contract** - Manages user identities, registration, and verification status
2. **Verification Oracle Contract** - Handles verification requests and provides trusted oracle services

## Features

### Identity Registry
- **Identity Registration**: Users can register their identity with personal information
- **Identity Updates**: Registered users can update their identity information
- **Verification Management**: Track verification status and history
- **Identity Revocation**: Administrative ability to revoke identities when necessary
- **Query Functions**: Read-only functions to check identity status and details

### Verification Oracle
- **Verification Requests**: Submit requests for identity verification
- **Oracle Management**: Set and manage trusted oracles
- **Scoring System**: Implement identity scoring based on verification results
- **Request Tracking**: Monitor verification request status and outcomes

## Smart Contract Architecture

### Data Structures

#### Identity Registry
- **Identities Map**: `principal -> {info: buff, verified: bool, timestamp: uint, score: uint}`
- **Verification Requests**: Track pending and completed verifications
- **Admin Controls**: Contract owner and verification authority management

#### Verification Oracle
- **Oracle Registry**: Trusted oracle addresses and their capabilities
- **Verification Requests**: Request ID mapping to verification details
- **Scoring Database**: Identity scores and verification history
- **Request Status**: Track request lifecycle from submission to completion

### Key Functions

#### Public Functions
- `register-identity`: Register new identity
- `update-identity`: Update existing identity information
- `verify-identity`: Administrative verification function
- `revoke-identity`: Revoke identity access
- `request-verification`: Submit verification request to oracle
- `oracle-respond`: Oracle response to verification requests
- `set-oracle`: Add/remove trusted oracles

#### Read-Only Functions
- `get-identity`: Retrieve identity information
- `is-verified`: Check verification status
- `get-score`: Get identity verification score
- `get-request-status`: Check verification request status

## Technical Specifications

- **Language**: Clarity smart contracts
- **Blockchain**: Stacks
- **Testing Framework**: Clarinet
- **Minimum Contract Size**: 150+ lines of code each
- **Security Features**: Input validation, access controls, data integrity checks

## Project Structure

```
├── contracts/
│   ├── identity-registry.clar
│   └── verification-oracle.clar
├── tests/
│   ├── identity-registry_test.ts
│   └── verification-oracle_test.ts
├── settings/
│   ├── Devnet.toml
│   ├── Testnet.toml
│   └── Mainnet.toml
├── Clarinet.toml
├── package.json
└── README.md
```

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing
- Git for version control

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/adeboyemicheal/decentralized-identity-verification.git
   cd decentralized-identity-verification
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run contract syntax checks:
   ```bash
   clarinet check
   ```

4. Run tests:
   ```bash
   clarinet test
   ```

### Development Workflow

1. **Contract Development**: Implement smart contracts in the `contracts/` directory
2. **Testing**: Write comprehensive tests in the `tests/` directory
3. **Validation**: Use `clarinet check` to validate contract syntax
4. **Deployment**: Configure deployment settings in `settings/` files

## Security Considerations

- **Access Control**: Only authorized principals can perform administrative functions
- **Data Validation**: All inputs are validated for type safety and business logic
- **State Management**: Proper state transitions and consistency checks
- **Oracle Trust**: Multi-oracle validation to prevent single points of failure
- **Privacy Protection**: Sensitive identity data is handled securely

## Use Cases

1. **KYC/AML Compliance**: Financial institutions can verify customer identities
2. **Digital Identity**: Establish trusted digital identities for online services
3. **Document Verification**: Verify authenticity of important documents
4. **Professional Credentials**: Verify professional qualifications and certifications
5. **Age Verification**: Confirm age requirements for restricted services

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## Testing

The project includes comprehensive test suites for both contracts:

```bash
# Run all tests
clarinet test

# Check contract syntax
clarinet check

# Start local development environment
clarinet integrate
```

## Deployment

Deployment configurations are available for:
- **Devnet**: Local development and testing
- **Testnet**: Pre-production testing
- **Mainnet**: Production deployment

Configure your deployment settings in the respective `settings/` files.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Roadmap

- [ ] Multi-signature oracle support
- [ ] Enhanced privacy features
- [ ] Integration with external identity providers
- [ ] Mobile SDK development
- [ ] Governance token implementation

## Support

For support and questions:
- Create an issue on GitHub
- Review the documentation
- Check existing discussions and solutions

---

Built with ❤️ using Clarity and Stacks blockchain technology.
