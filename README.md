# Tokenized Decentralized Birdhouse Construction Networks

A blockchain-based ecosystem for coordinating community-driven birdhouse construction, from design to occupancy monitoring.

## Overview

This system consists of five interconnected smart contracts that manage the entire lifecycle of birdhouse construction:

1. **Design Specification Contract** - Provides species-appropriate birdhouse blueprints
2. **Material Sourcing Contract** - Manages wood and hardware procurement for construction
3. **Assembly Coordination Contract** - Organizes community birdhouse building workshops
4. **Installation Service Contract** - Handles proper mounting and placement procedures
5. **Occupancy Monitoring Contract** - Tracks bird usage and nesting success rates

## Architecture

### Smart Contracts

- \`design-specification.clar\` - Blueprint management and species requirements
- \`material-sourcing.clar\` - Supply chain and procurement tracking
- \`assembly-coordination.clar\` - Workshop scheduling and participant management
- \`installation-service.clar\` - Installation coordination and location tracking
- \`occupancy-monitoring.clar\` - Bird usage analytics and success metrics

### Token Economics

The system uses a native token (BIRD) to incentivize participation across all phases:
- Blueprint contributors earn tokens for approved designs
- Material suppliers receive tokens for quality materials
- Workshop organizers are rewarded for successful events
- Installation teams earn tokens for proper placement
- Monitoring participants receive tokens for accurate data collection

## Getting Started

### Prerequisites

- Clarity development environment
- Node.js for testing
- Vitest for test execution

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts to testnet/mainnet

### Usage

Each contract can be deployed independently and manages its specific domain:

1. **Design Phase**: Submit and approve birdhouse blueprints
2. **Sourcing Phase**: Coordinate material procurement
3. **Assembly Phase**: Schedule and manage building workshops
4. **Installation Phase**: Coordinate proper placement
5. **Monitoring Phase**: Track occupancy and success rates

## Contract Interactions

While contracts are designed to be independent, they share common data structures and token rewards to create a cohesive ecosystem.

## Testing

Run the test suite with:
\`\`\`bash
npm test
\`\`\`

Tests cover all contract functions, edge cases, and integration scenarios.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License - see LICENSE file for details
