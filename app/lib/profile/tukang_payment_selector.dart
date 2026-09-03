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

  // E-wallets: dana, ovo, gopay, shopeepay
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

  // State untuk checkbox "samakan nomor"
  final Map<String, bool> _ewalletSameAsPrevious = {
    'DANA': false,
    'OVO': false,
    'GoPay': false,
    'ShopeePay': false,
  };

  // Banks: BCA, BNI, BRI, Mandiri, BSI
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

    // Muat initial details jika ada
    final ewalletData = widget.initialDetails['ewallet'];
    if (ewalletData is Map) {
      ewalletData.forEach((key, val) {
        final normKey = _normalizeKey(key.toString());
        if (_ewalletControllers.containsKey(normKey) && val != null) {
          _ewalletSelected[normKey] = true;
          _ewalletControllers[normKey]!.text = val.toString();
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
        }
      });
    }

    // Pasang listener untuk propagate perubahan ke parent
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

  // Mendapatkan nomor e-wallet pertama yang sudah terisi dan daftar nama e-wallet yang memiliki nomor tersebut
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. CASH (TUNAI)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: const Text('Tunai (Cash)', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Menerima pembayaran uang tunai langsung di tempat.', style: TextStyle(fontSize: 12)),
          value: _enableCash,
          onChanged: (val) {
            setState(() {
              _enableCash = val ?? false;
              _emitChange();
            });
          },
        ),

        const Divider(height: 24),

        // 2. E-WALLET
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: const Text('E-Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('DANA, OVO, GoPay, ShopeePay', style: TextStyle(fontSize: 12)),
          value: _enableEwallet,
          onChanged: (val) {
            setState(() {
              _enableEwallet = val ?? false;
              _emitChange();
            });
          },
        ),

        if (_enableEwallet) ...[
          Container(
            margin: const EdgeInsets.only(left: 8, bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih E-Wallet yang Anda Sediakan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                ..._ewalletSelected.keys.map((ewalletName) {
                  final isSelected = _ewalletSelected[ewalletName] ?? false;
                  final existingInfo = _getExistingEwalletNumberAndNames(ewalletName);
                  final isSameChecked = _ewalletSameAsPrevious[ewalletName] ?? false;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.primary,
                          title: Text(
                            ewalletName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              _ewalletSelected[ewalletName] = val ?? false;
                              if (!(_ewalletSelected[ewalletName]!)) {
                                _ewalletControllers[ewalletName]!.clear();
                                _ewalletSameAsPrevious[ewalletName] = false;
                              }
                              _emitChange();
                            });
                          },
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          // Jika ada nomor e-wallet yang sudah terisi sebelumnya
                          if (existingInfo != null) ...[
                            Row(
                              children: [
                                Checkbox(
                                  value: isSameChecked,
                                  activeColor: AppColors.primary,
                                  onChanged: (checked) {
                                    setState(() {
                                      _ewalletSameAsPrevious[ewalletName] = checked ?? false;
                                      if (_ewalletSameAsPrevious[ewalletName]!) {
                                        _ewalletControllers[ewalletName]!.text = existingInfo.$1;
                                      }
                                      _emitChange();
                                    });
                                  },
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _ewalletSameAsPrevious[ewalletName] = !isSameChecked;
                                        if (_ewalletSameAsPrevious[ewalletName]!) {
                                          _ewalletControllers[ewalletName]!.text = existingInfo.$1;
                                        }
                                        _emitChange();
                                      });
                                    },
                                    child: Text(
                                      'Nomor $ewalletName sama dengan nomor ${existingInfo.$2.join(' dan ')}?',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          TextFormField(
                            controller: _ewalletControllers[ewalletName],
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Nomor $ewalletName',
                              hintText: 'Misal: 081234567890',
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              ],
            ),
          ),
        ],

        const Divider(height: 24),

        // 3. TRANSFER BANK
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: const Text('Transfer Bank', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('BCA, BNI, BRI, Mandiri, BSI', style: TextStyle(fontSize: 12)),
          value: _enableBank,
          onChanged: (val) {
            setState(() {
              _enableBank = val ?? false;
              _emitChange();
            });
          },
        ),

        if (_enableBank) ...[
          Container(
            margin: const EdgeInsets.only(left: 8, bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Rekening Bank yang Anda Miliki:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Nomor rekening tiap bank berbeda-beda, silakan isi manual nomor rekening bank pilihan Anda.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ..._bankSelected.keys.map((bankName) {
                  final isSelected = _bankSelected[bankName] ?? false;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isSelected ? AppColors.secondary : AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.secondary,
                          title: Text(
                            'Bank $bankName',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              _bankSelected[bankName] = val ?? false;
                              if (!(_bankSelected[bankName]!)) {
                                _bankControllers[bankName]!.clear();
                              }
                              _emitChange();
                            });
                          },
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bankControllers[bankName],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Nomor Rekening Bank $bankName',
                              hintText: 'Misal: 1234567890',
                              prefixIcon: const Icon(Icons.credit_card_outlined, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
