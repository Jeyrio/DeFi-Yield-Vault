# Yield Vault - DeFi Yield Farming on Stacks

A secure and efficient yield vault contract that allows users to deposit STX tokens and earn yield through automated strategies.

## Features

- **Secure Deposits**: Users can deposit STX tokens into the vault
- **Yield Generation**: Automatic yield calculation based on configurable rates
- **Flexible Withdrawals**: Users can withdraw their deposits plus earned yield
- **Admin Controls**: Vault management with pause/unpause functionality
- **Yield Claiming**: Separate function to claim earned yield without withdrawing principal

## Contract Functions

### Public Functions

- `deposit(amount)` - Deposit STX tokens into the vault
- `withdraw(amount)` - Withdraw STX tokens and earned yield
- `claim-yield()` - Claim earned yield without withdrawing principal

### Read-Only Functions

- `get-user-deposit(user)` - Get user's current deposit amount
- `get-total-deposits()` - Get total deposits in the vault
- `calculate-yield(user)` - Calculate current yield for a user
- `get-yield-rate()` - Get current yield rate
- `is-vault-paused()` - Check if vault is paused

### Admin Functions

- `set-yield-rate(new-rate)` - Update the yield rate (owner only)
- `pause-vault()` - Pause vault operations (owner only)
- `unpause-vault()` - Resume vault operations (owner only)

## Usage

1. Deploy the contract to Stacks blockchain
2. Users can deposit STX using the `deposit` function
3. Yield accrues automatically based on block height
4. Users can claim yield or withdraw their deposits at any time

## Security Features

- Reentrancy protection
- Access control for admin functions
- Emergency pause functionality
- Input validation and error handling

## Testing

Run tests with Clarinet:
\`\`\`bash
clarinet test
\`\`\`