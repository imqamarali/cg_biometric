// ---------------- MEMBERSHIP CARD ----------------
import 'package:flutter/material.dart';

Widget membershipCard(Map<String, dynamic> membership) {
  return Card(
    color: Colors.white,
    shadowColor: Colors.transparent,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.network(
              membership['image'] ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey.shade200, width: 80, height: 80),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      membership['member_name'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      membership['relation'] ?? 'N/A',
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      membership['sodowo'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (membership['consumer_no'] != null)
                  Row(
                    children: [
                      const Icon(Icons.numbers, size: 16),
                      const SizedBox(width: 4),
                      const Text("Consumer No: "),
                      const SizedBox(width: 8),
                      Text(
                        "${membership['consumer_no'] ?? 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                if (membership['plot_no'] != null)
                  Row(
                    children: [
                      const Icon(Icons.home, size: 16),
                      const SizedBox(width: 4),
                      const Text("Plot No: "),
                      const SizedBox(width: 8),
                      Text(
                        "${membership['plot_no'] ?? 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(" | "),
                      const SizedBox(width: 4),
                      Text(
                        "${membership['size'] ?? 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(" | "),
                      const SizedBox(width: 4),
                      Text(
                        "${membership['sector_name'] ?? 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                if (membership['comment'] != null) const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    membership['comment'] ?? 'Status Unknown',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------- LEFT COLUMN ----------------
Widget buildLeftColumn(List<dynamic>? memberships) {
  if (memberships == null) {
    return Center(
      child: Text(
        'Enter CNIC and press Enter',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
  if (memberships.isEmpty) {
    return const Center(child: Text('No memberships found'));
  }
  return Column(children: memberships.map((m) => membershipCard(m)).toList());
}

Widget buildInfoPanel(ThemeData theme, bool deviceConnected) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: theme.primaryColor.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verify a registered user using fingerprint authentication.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: deviceConnected
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    deviceConnected ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: deviceConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deviceConnected ? 'Device Ready' : 'Device Not Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: deviceConnected
                          ? Colors.green
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStepRow(
                Icons.edit,
                'Enter CNIC of the registered user',
              ),
            ),
            Expanded(
              child: _buildStepRow(
                Icons.fingerprint,
                'Place finger on biometric sensor',
              ),
            ),
            Expanded(
              child: _buildStepRow(
                Icons.verified,
                'System will verify and fetch records',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildStepRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
        ),
      ],
    ),
  );
}
