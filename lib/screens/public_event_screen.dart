import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/event_service.dart';
import '../theme/brand.dart';
import '../utils/deep_link.dart';
import '../utils/event_time.dart';
import '../utils/spots_remaining.dart';
import '../widgets/responsive.dart';

/// A shared drive, for someone who is not signed in. Pops `true` when they
/// choose to sign in, so the drive opens after login.
class PublicEventScreen extends StatefulWidget {
  final String eventId;

  const PublicEventScreen({super.key, required this.eventId});

  @override
  State<PublicEventScreen> createState() => _PublicEventScreenState();
}

class _PublicEventScreenState extends State<PublicEventScreen> {
  late final Future<EventModel?> _event;

  @override
  void initState() {
    super.initState();
    _event = Provider.of<EventService>(
      context,
      listen: false,
    ).fetchEventById(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventModel?>(
      future: _event,
      builder: (context, snapshot) {
        final e = snapshot.data;
        // Hidden drives stay hidden here too, as on the public page.
        final drive =
            e != null &&
                guestCanSeeDrive(
                  status: e.status,
                  shareUrlProvided: e.shareUrlProvided,
                  shareUrl: e.shareUrl,
                )
            ? e
            : null;
        return Scaffold(
          backgroundColor: Brand.mist,
          // The theme's forest app bar: its white title and icon styles
          // override a foregroundColor, so a light bar hid the back button.
          appBar: AppBar(title: const Text('Volunteer drive')),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : drive == null
              ? const _Unavailable()
              : _DriveDetails(drive: drive),
          bottomNavigationBar:
              drive != null &&
                  guestCanApply(status: drive.status, end: drive.endTime)
              ? const _SignInBar()
              : null,
        );
      },
    );
  }
}

class _DriveDetails extends StatelessWidget {
  final EventModel drive;

  const _DriveDetails({required this.drive});

  @override
  Widget build(BuildContext context) {
    final e = drive;
    return ResponsiveCenter(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            e.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Brand.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            e.isOrganizerVerified
                ? '${e.organizerName} · Verified organizer'
                : e.organizerName,
            style: const TextStyle(color: Brand.inkMuted),
          ),
          const SizedBox(height: 16),
          _Fact(
            icon: Icons.event,
            text:
                '${formatLocalDate(e.startTime)}, '
                '${formatLocalTime(e.startTime)} – ${formatLocalTime(e.endTime)}',
          ),
          _Fact(
            icon: Icons.place_outlined,
            text: e.isOnline ? 'Online' : e.address,
          ),
          _Fact(icon: Icons.cake_outlined, text: 'Minimum age: ${e.minAge}+'),
          _Fact(
            icon: Icons.group_outlined,
            text: placesLabel(
              status: e.status,
              needed: e.volunteersNeeded,
              approved: e.approvedCount,
              end: e.endTime,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            e.description,
            style: const TextStyle(height: 1.5, color: Brand.ink),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This drive is not available. It may have been cancelled.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Offered only while the drive takes sign-ups.
class _SignInBar extends StatelessWidget {
  const _SignInBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Brand.forest,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Sign in to apply'),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Brand.growth),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Brand.ink)),
          ),
        ],
      ),
    );
  }
}
