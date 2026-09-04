import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../shared/models/user_profile.dart';

class TukangPaymentSelector extends StatefulWidget {
  final List<PaymentMethod> initialMethods;
  final Map<String, dynamic> initialDetails;
  final void Function(List<PaymentMethod> methods, Map<String, dynamic> details) onChanged;

  const TukangPaymentSelector({
    super.key,
    this.initialMethods = const [PaymentMethod.cash],
    this.initialDetails = const {},
    required this.onChanged,
  });

  @override
  State<TukangPaymentSelector> createState() => _TukangPaymentSelectorState();
}

class _TukangPaymentSelectorState extends State<TukangPaymentSelector> {
  bool _enableCash = true;
  bool _enableEwallet = false;
  bool _enableBank = false;

  final Map<String, bool> _ewalletSelected = {
    'DANA': false,
    'OVO': false,
    'GoPay': false,
    'ShopeePay': false,
  };

  final Map<String, TextEditingController> _ewalletControllers = {
    'DANA': TextEditingController(),
    'OVO': TextEditingController(),
    'GoPay': TextEditingController(),
    'ShopeePay': TextEditingController(),
  };

  final Map<String, bool> _bankSelected = {
    'BCA': false,
    'BNI': false,
    'BRI': false,
    'Mandiri': false,
    'BSI': false,
  };

  final Map<String, TextEditingController> _bankControllers = {
    'BCA': TextEditingController(),
    'BNI': TextEditingController(),
    'BRI': TextEditingController(),
    'Mandiri': TextEditingController(),
    'BSI': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _enableCash = widget.initialMethods.contains(PaymentMethod.cash);
    _enableEwallet = widget.initialMethods.contains(PaymentMethod.ewallet);
    _enableBank = widget.initialMethods.contains(PaymentMethod.bankTransfer);

    final ewalletData = widget.initialDetails['ewallet'];
    if (ewalletData is Map) {
      ewalletData.forEach((key, val) {
        final normKey = _normalizeKey(key.toString());
        if (_ewalletControllers.containsKey(normKey) && val != null) {
          _ewalletSelected[normKey] = true;
          _ewalletControllers[normKey]!.text = val.toString();
          _enableEwallet = true;
        }
      });
    }

    final bankData = widget.initialDetails['bank_transfer'] ?? widget.initialDetails['bank'];
    if (bankData is Map) {
      bankData.forEach((key, val) {
        final normKey = _normalizeKey(key.toString());
        if (_bankControllers.containsKey(normKey) && val != null) {
          _bankSelected[normKey] = true;
          _bankControllers[normKey]!.text = val.toString();
          _enableBank = true;
        }
      });
    }

    for (final c in _ewalletControllers.values) {
      c.addListener(_emitChange);
    }
    for (final c in _bankControllers.values) {
      c.addListener(_emitChange);
    }
  }

  String _normalizeKey(String key) {
    final lk = key.toLowerCase();
    if (lk == 'dana') return 'DANA';
    if (lk == 'ovo') return 'OVO';
    if (lk == 'gopay') return 'GoPay';
    if (lk == 'shopeepay') return 'ShopeePay';
    if (lk == 'bca') return 'BCA';
    if (lk == 'bni') return 'BNI';
    if (lk == 'bri') return 'BRI';
    if (lk == 'mandiri') return 'Mandiri';
    if (lk == 'bsi') return 'BSI';
    return key;
  }

  @override
  void dispose() {
    for (final c in _ewalletControllers.values) {
      c.dispose();
    }
    for (final c in _bankControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emitChange() {
    final methods = <PaymentMethod>[];
    if (_enableCash) methods.add(PaymentMethod.cash);
    if (_enableEwallet && _ewalletSelected.values.any((v) => v)) {
      methods.add(PaymentMethod.ewallet);
    }
    if (_enableBank && _bankSelected.values.any((v) => v)) {
      methods.add(PaymentMethod.bankTransfer);
    }

    final ewalletMap = <String, String>{};
    _ewalletSelected.forEach((name, isSelected) {
      if (isSelected && _ewalletControllers[name]!.text.trim().isNotEmpty) {
        ewalletMap[name.toLowerCase()] = _ewalletControllers[name]!.text.trim();
      }
    });

    final bankMap = <String, String>{};
    _bankSelected.forEach((name, isSelected) {
      if (isSelected && _bankControllers[name]!.text.trim().isNotEmpty) {
        bankMap[name.toLowerCase()] = _bankControllers[name]!.text.trim();
      }
    });

    final details = <String, dynamic>{
      'cash': _enableCash,
      'ewallet': ewalletMap,
      'bank_transfer': bankMap,
    };

    widget.onChanged(methods, details);
  }

  (String, List<String>)? _getExistingEwalletNumberAndNames(String currentName) {
    String? foundNumber;
    final matchingNames = <String>[];

    for (final entry in _ewalletSelected.entries) {
      if (entry.key != currentName && entry.value) {
        final text = _ewalletControllers[entry.key]!.text.trim();
        if (text.isNotEmpty) {
          foundNumber ??= text;
          if (text == foundNumber) {
            matchingNames.add(entry.key);
          }
        }
      }
    }

    if (foundNumber != null && matchingNames.isNotEmpty) {
      return (foundNumber, matchingNames);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. KARTU PEMBAYARAN TUNAI (CASH)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _enableCash ? AppColors.primary : AppColors.border,
              width: _enableCash ? 1.5 : 1,
            ),
          ),
          color: _enableCash ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _enableCash
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payments_outlined,
                    color: _enableCash ? AppColors.primary : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tunai (Cash)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Menerima uang tunai langsung dari customer saat pekerjaan selesai.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enableCash,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _enableCash = val;
                      _emitChange();
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. KARTU E-WALLET DIGITAL
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _enableEwallet ? Colors.blue.shade400 : AppColors.border,
              width: _enableEwallet ? 1.5 : 1,
            ),
          ),
          color: _enableEwallet ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _enableEwallet ? Colors.blue.shade100 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: _enableEwallet ? Colors.blue.shade700 : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'E-Wallet',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Menerima pembayaran lewat DANA, OVO, GoPay, atau ShopeePay.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enableEwallet,
                      activeThumbColor: Colors.blue.shade700,
                      onChanged: (val) {
                        setState(() {
                          _enableEwallet = val;
                          _emitChange();
                        });
                      },
                    ),
                  ],
                ),

                if (_enableEwallet) ...[
                  const Divider(height: 24),
                  const Text(
                    'Pilih Dompet Digital Anda:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Chips Pilihan E-Wallet
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ewalletSelected.keys.map((name) {
                      final isSelected = _ewalletSelected[name] ?? false;
                      return FilterChip(
                        avatar: Icon(
                          isSelected ? Icons.check_circle : Icons.account_balance_wallet,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.blue.shade700,
                        ),
                        label: Text(name),
                        selected: isSelected,
                        selectedColor: Colors.blue.shade700,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _ewalletSelected[name] = val;
                            if (!val) {
                              _ewalletControllers[name]!.clear();
                            }
                            _emitChange();
                          });
                        },
                      );
                    }).toList(),
                  ),

                  // Fields Input Nomor E-Wallet
                  const SizedBox(height: 12),
                  ..._ewalletSelected.entries.where((e) => e.value).map((entry) {
                    final name = entry.key;
                    final existing = _getExistingEwalletNumberAndNames(name);

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nomor Akun $name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                              ),
                              if (existing != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  icon: const Icon(Icons.copy, size: 13),
                                  label: Text(
                                    'Nomor $name sama dengan nomor ${existing.$2.join(' dan ')}?',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _ewalletControllers[name]!.text = existing.$1;
                                      _emitChange();
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _ewalletControllers[name],
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Nomor $name',
                              hintText: 'Misal: 081234567890',
                              prefixIcon: const Icon(Icons.phone_android, size: 18, color: Colors.blue),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3. KARTU TRANSFER BANK
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _enableBank ? AppColors.secondary : AppColors.border,
              width: _enableBank ? 1.5 : 1,
            ),
          ),
          color: _enableBank ? AppColors.secondary.withValues(alpha: 0.04) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _enableBank
                            ? AppColors.secondary.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: _enableBank ? AppColors.secondary : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer Bank',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Menerima pembayaran lewat transfer rekening bank (BCA, BNI, BRI, dll).',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enableBank,
                      activeThumbColor: AppColors.secondary,
                      onChanged: (val) {
                        setState(() {
                          _enableBank = val;
                          _emitChange();
                        });
                      },
                    ),
                  ],
                ),

                if (_enableBank) ...[
                  const Divider(height: 24),
                  const Text(
                    'Pilih Bank yang Anda Miliki:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Chips Pilihan Bank
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bankSelected.keys.map((name) {
                      final isSelected = _bankSelected[name] ?? false;
                      return FilterChip(
                        avatar: Icon(
                          isSelected ? Icons.check_circle : Icons.credit_card,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.secondary,
                        ),
                        label: Text('Bank $name'),
                        selected: isSelected,
                        selectedColor: AppColors.secondary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _bankSelected[name] = val;
                            if (!val) {
                              _bankControllers[name]!.clear();
                            }
                            _emitChange();
                          });
                        },
                      );
                    }).toList(),
                  ),

                  // Fields Input Nomor Rekening Manual
                  const SizedBox(height: 12),
                  ..._bankSelected.entries.where((e) => e.value).map((entry) {
                    final name = entry.key;

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor Rekening Bank $name',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _bankControllers[name],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Nomor Rekening Bank $name',
                              hintText: 'Misal: 1234567890',
                              prefixIcon: const Icon(Icons.credit_card, size: 18, color: AppColors.secondary),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
