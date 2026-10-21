import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/payments_service.dart';
import '../widgets/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

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
        Provider.of<PaymentsService>(
          context,
          listen: false,
        ).fetchHistory(auth.token!);
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
    // Premium plans are sold only to verified NGO hosts; the API returns 403
    // for everyone else, so do not offer them a purchase flow.
    final userType = auth.currentUser?.userType;
    final canSubscribe =
        (userType == 'ORGANIZER' || userType == 'ADMIN') &&
        auth.currentUser?.isVerified == true;

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
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'DONATE'),
            Tab(text: 'SUBSCRIBE'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 840,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDonateTab(auth, payments),
            _buildSubscribeTab(auth, payments, canSubscribe),
            _buildHistoryTab(payments),
          ],
        ),
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
                const Icon(
                  Icons.volunteer_activism,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Make a Difference',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your donation powers local NGOs and volunteer drives across communities.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Select Amount (₹)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    ),
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
        ],
      ),
    );
  }

  void _handleDonate(
    AuthService auth,
    PaymentsService payments,
    double amount,
  ) async {
    if (auth.token == null) return;

    final result = await payments.createDonation(auth.token!, amount);

    if (!mounted) return;

    if (result['success'] == true) {
      _showCheckoutDialog(result['txRef'], amount, result['checkoutUrl']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to initiate donation'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Settlement happens only through the gateway's signed webhook (or an
  /// admin), never from the app — so all the app can do is hand the user to
  /// the checkout page and refresh history afterwards. The previous dialog
  /// called a removed /payments/verify endpoint and then announced
  /// "Payment successful" regardless of the result.
  void _showCheckoutDialog(String txRef, double amount, String? checkoutUrl) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final paymentsService = Provider.of<PaymentsService>(
      context,
      listen: false,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Complete your payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will be taken to the secure checkout page. Your payment '
              'history updates once the gateway confirms the transaction.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Not now',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = checkoutUrl != null
                  ? Uri.tryParse(checkoutUrl)
                  : null;
              var launched = false;
              if (uri != null) {
                try {
                  launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  launched = false;
                }
              }
              if (!mounted) return;
              if (!launched) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Checkout is not available right now. The transaction '
                      'was recorded as pending — please try again later.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              if (auth.token != null) {
                await paymentsService.fetchHistory(auth.token!);
              }
              if (!mounted) return;
              _tabController.animateTo(2); // Jump to History
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Continue to checkout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeTab(
    AuthService auth,
    PaymentsService payments,
    bool canSubscribe,
  ) {
    if (!canSubscribe) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 56,
                color: Color(0xFF64748B),
              ),
              SizedBox(height: 16),
              Text(
                'Premium plans are for verified NGO hosts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Once your organization is verified by an administrator, '
                'subscription plans appear here.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Unlock Premium Organizer Tools',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Support Voluntree with a monthly or annual plan.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _PlanCard(
            title: 'Monthly Plan',
            price: '₹499',
            period: '/month',
            accent: const Color(0xFF6366F1),
            onSubscribe: () => _handleSubscribe(auth, payments, 'MONTHLY'),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: 'Annual Plan',
            price: '₹4,999',
            period: '/year',
            saving: 'Save ₹989',
            accent: const Color(0xFFD97706),
            onSubscribe: () => _handleSubscribe(auth, payments, 'ANNUAL'),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(
    AuthService auth,
    PaymentsService payments,
    String plan,
  ) async {
    if (auth.token == null) return;

    final result = await payments.createSubscription(auth.token!, plan);

    if (!mounted) return;

    if (result['success'] == true) {
      final amount = plan == 'ANNUAL' ? 4999.0 : 499.0;
      _showCheckoutDialog(result['txRef'], amount, result['checkoutUrl']);
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
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (record.eventTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.eventTitle!,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${record.createdAt.day.toString().padLeft(2, '0')} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][record.createdAt.month - 1]} ${record.createdAt.year}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.currency} ${record.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
  final Color accent;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.saving,
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (saving != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    saving!,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: accent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                period,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Subscribe Now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              prefixStyle: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
              ),
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
                const SnackBar(
                  content: Text('Enter a valid amount'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }
            context
                .findAncestorStateOfType<_PaymentsScreenState>()
                ?._handleDonate(widget.auth, widget.payments, amount);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Donate',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
