/// Opciones reutilizables de bancos y tipos de cuenta disponibles en la app.
const String kBancoEstadoName = 'Banco Estado';
const String kCuentaRutType = 'Cuenta RUT';

const List<String> kBankOptions = <String>[
  'Banco de Chile',
  kBancoEstadoName,
  'Banco Santander',
  'Banco BCI',
  'Banco Itaú',
  'Banco Security',
  'Banco Scotiabank',
  'Banco Falabella',
  'Banco Ripley',
  'Banco Consorcio',
  'Banco Internacional',
  'Banco BICE',
  'Banco BTG Pactual',
  'Banco HSBC',
];

const List<String> _kCommonAccountTypes = <String>[
  'Cuenta corriente',
  'Cuenta vista',
  'Cuenta de ahorro',
];

const List<String> kBancoEstadoAccountTypes = <String>[
  ..._kCommonAccountTypes,
  kCuentaRutType,
];

/// Devuelve la lista de tipos de cuenta permitidos para el banco dado.
List<String> accountTypeOptionsForBank(String? bankName) {
  final String? normalized = bankName?.trim();
  if (normalized == kBancoEstadoName) {
    return kBancoEstadoAccountTypes;
  }
  return _kCommonAccountTypes;
}