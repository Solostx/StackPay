# StackPay 💰

A peer-to-peer multi-token invoicing and recurring payment system built on Stacks blockchain using Clarity smart contracts.

## Overview

StackPay enables freelancers and businesses to create, send, and track crypto invoices with built-in payment enforcement and recurring payment functionality. All transactions are secured by Bitcoin through the Stacks layer. The system supports STX payments with a foundation for future multi-token support.

## Features

- 📄 **Invoice Creation**: Generate professional invoices with customizable amounts and descriptions
- 🔄 **Recurring Payments**: Set up automated recurring invoices with flexible intervals
- 🪙 **Multi-token Ready**: Foundation for STX and future SIP-10 token support
- 💸 **Secure Payments**: Direct STX transfers with built-in escrow and fee handling
- 📊 **Payment Tracking**: Monitor invoice status and payment history
- ⏰ **Due Date Management**: Automatic expiration and overdue detection
- 🔒 **Access Control**: Creator-only invoice management and cancellation
- ⚡ **Token Framework**: Admin-controlled framework for future token expansion

## Smart Contract Functions

### Read-Only Functions
- `get-invoice(invoice-id)` - Retrieve invoice details
- `get-user-invoices(user)` - Get all invoices created by a user
- `get-recipient-invoices(recipient)` - Get all invoices for a recipient
- `is-invoice-overdue(invoice-id)` - Check if invoice is past due date
- `is-token-supported(token-contract)` - Check if a SIP-10 token is supported
- `calculate-fee(amount)` - Calculate platform fee for an amount

### Public Functions
- `create-invoice(recipient, amount, description, due-blocks, token-contract, token-decimals)` - Create a one-time invoice
- `create-recurring-invoice(recipient, amount, description, due-blocks, interval-blocks, token-contract, token-decimals)` - Create recurring invoice
- `pay-invoice(invoice-id)` - Pay an outstanding invoice
- `pay-recurring-invoice(invoice-id)` - Pay next recurring payment
- `cancel-invoice(invoice-id)` - Cancel unpaid invoice (creator only)

### Admin Functions
- `update-contract-fees(new-fees)` - Update platform fee percentage
- `add-supported-token(token-contract)` - Add SIP-10 token to whitelist
- `remove-supported-token(token-contract)` - Remove SIP-10 token from whitelist

## Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) CLI tool
- STX wallet for testing
- SIP-10 token contracts for multi-token functionality

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

## Usage Examples

### STX Invoices

```clarity
;; Create a $100 STX invoice due in 1 week (1008 blocks)
(contract-call? .stackpay create-invoice 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u100000000 
  u"Web Development Services" 
  u1008 
  none ;; STX payment
  u6   ;; STX decimals
)

;; Create recurring monthly invoice for $50 STX
(contract-call? .stackpay create-recurring-invoice 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u50000000 
  u"Monthly Consulting" 
  u1008 
  u4032 
  none ;; STX payment
  u6   ;; STX decimals
)

;; Pay invoice #1
(contract-call? .stackpay pay-invoice u1)
```

### Future SIP-10 Token Support

The contract includes the framework for SIP-10 token support:

```clarity
;; Admin can prepare for future token support
(contract-call? .stackpay add-supported-token .future-token)

;; Invoice structure supports token specification
(contract-call? .stackpay create-invoice 
  recipient 
  amount 
  description 
  due-blocks 
  (some .future-token) ;; Future token support
  token-decimals
)
```

### Token Management

```clarity
;; Admin can prepare token whitelist for future expansion
(contract-call? .stackpay add-supported-token .future-token)

;; Remove token from whitelist
(contract-call? .stackpay remove-supported-token .old-token)

;; Check if token is whitelisted
(contract-call? .stackpay is-token-supported .some-token)
```

## Multi-token Framework

StackPay includes a framework for future multi-token support:

- **STX**: Native Stacks token (fully supported)
- **SIP-10 Tokens**: Framework ready for future implementation

### Token Framework Features

- Token contract storage in invoice data structure
- Token decimal precision tracking
- Admin-controlled token whitelist system
- Extensible payment processing architecture

### Current Limitations

- **STX Only**: Current version supports STX payments only
- **SIP-10 Framework**: Data structures ready but implementation pending
- **Future Expansion**: Contract designed for easy SIP-10 integration

## Fee Structure

The contract charges a 0.5% fee on all successful payments to maintain the platform and ensure sustainability. Fees are paid in the same token as the invoice.

## Security Considerations

- All payments are atomic - they either complete fully or revert
- Invoice creators can only cancel their own unpaid invoices
- Recurring payments require explicit calls to prevent unexpected charges
- Built-in validation prevents invalid amounts and self-payments
- Token whitelist prevents unauthorized token usage
- Proper error handling prevents "unchecked data" issues
- All parameters are validated before processing

## Error Codes

- `u100` - Not authorized
- `u101` - Invoice not found
- `u102` - Invoice already paid
- `u103` - Insufficient payment
- `u104` - Invoice expired
- `u105` - Invalid amount
- `u106` - Invalid recipient
- `u107` - Recurring payment not due
- `u108` - Invalid interval
- `u109` - Invalid due blocks
- `u110` - Invalid description
- `u111` - Invalid fee
- `u112` - Invalid token
- `u113` - Token transfer failed
- `u114` - Unsupported token

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🚀 Future Roadmap

StackPay is designed with extensibility in mind. Here are planned future enhancements:

### **Phase 2: Multi-token Ecosystem**
- **Multi-token Support** - Accept payments in other SIP-10 tokens beyond STX
- **Token Analytics** - Track payment patterns across different tokens
- **Cross-token Conversion** - Automatic token swapping for payments

### **Phase 3: Enhanced User Experience**
- **Invoice Templates** - Predefined templates for common service types
- **Partial Payments** - Allow installment payments for large invoices
- **Invoice Analytics** - Dashboard with payment trends and insights
- **Mobile App Integration** - Native mobile app for invoice management

### **Phase 4: Enterprise Features**
- **Multi-signature Approval** - Require multiple approvals for high-value invoices
- **Payment Escrow** - Hold payments in escrow until service completion
- **Tax Integration** - Automatic tax calculation and reporting features
- **Invoice Notifications** - Email/SMS reminders for upcoming due dates

### **Phase 5: Advanced Capabilities**
- **Dispute Resolution** - Built-in arbitration system for payment disputes
- **Smart Contract Automation** - Automated invoice generation based on milestones
- **Integration APIs** - Connect with popular accounting and CRM systems
- **Advanced Analytics** - ML-powered insights and payment predictions

### **Phase 6: Ecosystem Expansion**
- **Marketplace Integration** - Connect with freelance and service marketplaces
- **DeFi Integration** - Yield farming on held funds and liquidity provision
- **Cross-chain Support** - Expand beyond Stacks to other blockchain networks
- **Enterprise Dashboard** - Advanced reporting and team management features

Each phase builds upon the solid foundation of the current STX-based system, ensuring stability while adding powerful new capabilities for users and businesses.

Built with ❤️ on Stacks blockchain