import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/payments_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.token != null) {
        Provider.of<PaymentsService>(context, listen: false).fetchHistory(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final payments = Provider.of<PaymentsService>(context);
    final isOrganizer = auth.currentUser?.userType == 'ORGANIZER';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Payments & Donations',
          style: GoogleFonts.plusJakartaSans(
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'DONATE'),
            Tab(text: 'SUBSCRIBE'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDonateTab(auth, payments),
          _buildSubscribeTab(auth, payments, isOrganizer),
          _buildHistoryTab(payments),
        ],
      ),
    );
  }

  Widget _buildDonateTab(AuthService auth, PaymentsService payments) {
    final amounts = [100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volunteer_activism, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Make a Difference',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your donation powers local NGOs and volunteer drives across communities.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Select Amount (₹)',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: amounts.map((amount) {
              return GestureDetector(
                onTap: () => _handleDonate(auth, payments, amount),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '₹${amount.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Or enter custom amount',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 10),
          _CustomDonateInput(auth: auth, payments: payments),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Secured via encrypted gateway. All transactions are 256-bit SSL protected.',
                    style: TextStyle(
                      color: const Color(0xFF10B981).withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleDonate(AuthService auth, PaymentsService payments, double amount) async {
    if (auth.token == null) return;

    final result = await payments.createDonation(auth.token!, amount);

    if (!mounted) return;

    if (result['success'] == true) {
      _showPaymentGatewayDialog(auth, payments, result['txRef'], amount);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to initiate donation'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPaymentGatewayDialog(
    AuthService auth,
    PaymentsService payments,
    String txRef,
    double amount,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Mock Payment Gateway',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ref: $txRef',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Simulate a payment outcome:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await payments.verifyTransaction(auth.token!, txRef, 'FAILED');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment failed or cancelled.'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await payments.verifyTransaction(auth.token!, txRef, 'SUCCESS');
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Payment successful! Thank you for your donation.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
              _tabController.animateTo(2); // Jump to History
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeTab(AuthService auth, PaymentsService payments, bool isOrganizer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            isOrganizer ? 'Unlock Premium Organizer Tools' : 'Go Premium Volunteer',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Supercharge your impact with exclusive features.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _PlanCard(
            title: 'Monthly Plan',
            price: '₹499',
            period: '/month',
            features: isOrganizer
                ? ['Featured event listings', 'Priority applicant filtering', 'Verified organizer badge', 'Advanced analytics']
                : ['Priority event matching', 'Certificate priority queue', 'Exclusive campaigns access', 'Ad-free experience'],
            accent: const Color(0xFF6366F1),
            onSubscribe: () => _handleSubscribe(auth, payments, 'MONTHLY'),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: 'Annual Plan',
            price: '₹4,999',
            period: '/year',
            saving: 'Save ₹989',
            features: isOrganizer
                ? ['All Monthly features', 'Unlimited event campaigns', 'Donation tracking dashboard', 'API access for integrations']
                : ['All Monthly features', 'Lifetime leaderboard badge', 'Priority customer support', 'Early access to new features'],
            accent: const Color(0xFFD97706),
            onSubscribe: () => _handleSubscribe(auth, payments, 'ANNUAL'),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(AuthService auth, PaymentsService payments, String plan) async {
    if (auth.token == null) return;

    final result = await payments.createSubscription(auth.token!, plan);

    if (!mounted) return;

    if (result['success'] == true) {
      final amount = plan == 'ANNUAL' ? 4999.0 : 499.0;
      _showPaymentGatewayDialog(auth, payments, result['txRef'], amount);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to initiate subscription'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildHistoryTab(PaymentsService payments) {
    final typeColors = {
      'DONATION': const Color(0xFF6366F1),
      'PREMIUM_SUBSCRIBER': const Color(0xFFD97706),
      'FEATURED_EVENT_FEE': const Color(0xFF10B981),
    };
    final typeIcons = {
      'DONATION': Icons.volunteer_activism_outlined,
      'PREMIUM_SUBSCRIBER': Icons.workspace_premium_outlined,
      'FEATURED_EVENT_FEE': Icons.star_outline,
    };
    final typeLabels = {
      'DONATION': 'Donation',
      'PREMIUM_SUBSCRIBER': 'Subscription',
      'FEATURED_EVENT_FEE': 'Event Promotion',
    };

    if (payments.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    if (payments.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.history.length,
      itemBuilder: (ctx, i) {
        final record = payments.history[i];
        final color = typeColors[record.type] ?? const Color(0xFF64748B);
        final icon = typeIcons[record.type] ?? Icons.payment_outlined;
        final label = typeLabels[record.type] ?? record.type;
        final isSuccess = record.status == 'SUCCESS';
        final isPending = record.status == 'PENDING';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (record.eventTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.eventTitle!,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${record.createdAt.day.toString().padLeft(2, '0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][record.createdAt.month - 1]} ${record.createdAt.year}',
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.currency} ${record.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSuccess
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : isPending
                              ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSuccess
                            ? const Color(0xFF10B981)
                            : isPending
                                ? const Color(0xFFEAB308)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? saving;
  final List<String> features;
  final Color accent;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.saving,
    required this.features,
    required this.accent,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              if (saving != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(saving!, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: TextStyle(color: accent, fontSize: 32, fontWeight: FontWeight.bold)),
              Text(period, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: accent, size: 16),
                const SizedBox(width: 10),
                Text(f, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Subscribe Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomDonateInput extends StatefulWidget {
  final AuthService auth;
  final PaymentsService payments;

  const _CustomDonateInput({required this.auth, required this.payments});

  @override
  State<_CustomDonateInput> createState() => _CustomDonateInputState();
}

class _CustomDonateInputState extends State<_CustomDonateInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter amount (e.g. 750)',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_controller.text.trim());
            if (amount == null || amount <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.redAccent),
              );
              return;
            }
            context.findAncestorStateOfType<_PaymentsScreenState>()
                ?._handleDonate(widget.auth, widget.payments, amount);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Donate', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
