# StackPay 💰

A peer-to-peer STX-based invoicing and recurring payment system built on Stacks blockchain using Clarity smart contracts.

## Overview

StackPay enables freelancers and businesses to create, send, and track crypto invoices with built-in payment enforcement and recurring payment functionality. All transactions are secured by Bitcoin through the Stacks layer.

## Features

- 📄 **Invoice Creation**: Generate professional invoices with customizable amounts and descriptions
- 🔄 **Recurring Payments**: Set up automated recurring invoices with flexible intervals
- 💸 **Secure Payments**: Direct STX transfers with built-in escrow and fee handling
- 📊 **Payment Tracking**: Monitor invoice status and payment history
- ⏰ **Due Date Management**: Automatic expiration and overdue detection
- 🔒 **Access Control**: Creator-only invoice management and cancellation

## Smart Contract Functions

### Read-Only Functions
- `get-invoice(invoice-id)` - Retrieve invoice details
- `get-user-invoices(user)` - Get all invoices created by a user
- `get-recipient-invoices(recipient)` - Get all invoices for a recipient
- `is-invoice-overdue(invoice-id)` - Check if invoice is past due date

### Public Functions
- `create-invoice(recipient, amount, description, due-blocks)` - Create a one-time invoice
- `create-recurring-invoice(recipient, amount, description, due-blocks, interval-blocks)` - Create recurring invoice
- `pay-invoice(invoice-id)` - Pay an outstanding invoice
- `pay-recurring-invoice(invoice-id)` - Pay next recurring payment
- `cancel-invoice(invoice-id)` - Cancel unpaid invoice (creator only)

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) CLI tool
- STX wallet for testing

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/stackpay
cd stackpay
```

2. Run contract checks
```bash
clarinet check
```

3. Run tests
```bash
clarinet test
```

## Usage Example

```clarity
;; Create a $100 STX invoice due in 1 week (1008 blocks)
(contract-call? .stackpay create-invoice 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u100000000 u"Web Development Services" u1008)

;; Create recurring monthly invoice for $50 STX
(contract-call? .stackpay create-recurring-invoice 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u50000000 u"Monthly Consulting" u1008 u4032)

;; Pay invoice #1
(contract-call? .stackpay pay-invoice u1)
```

## Fee Structure

The contract charges a 0.5% fee on all successful payments to maintain the platform and ensure sustainability.

## Security Considerations

- All payments are atomic - they either complete fully or revert
- Invoice creators can only cancel their own unpaid invoices
- Recurring payments require explicit calls to prevent unexpected charges
- Built-in validation prevents invalid amounts and self-payments

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Built with ❤️ on Stacks blockchain