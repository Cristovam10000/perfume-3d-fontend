import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/date_math.dart';
import '../../domain/sales_models.dart';

/// Limite superior dos seletores de data: o usuario precisa poder remarcar um
/// vencimento ou uma previsao de recebimento para o futuro.
DateTime _datePickerLastDate() =>
    DateTime(DateTime.now().year + 10, DateTime.now().month, 1);

class ClientFormValue {
  final String name;
  final String phone;
  final String neighborhood;

  const ClientFormValue({
    required this.name,
    required this.phone,
    required this.neighborhood,
  });
}

class PaymentFormValue {
  final double value;
  final DateTime date;
  final String method;
  final String? notes;

  const PaymentFormValue({
    required this.value,
    required this.date,
    required this.method,
    this.notes,
  });
}

Future<ClientFormValue?> showClientForm(
  BuildContext context, {
  Cliente? client,
}) {
  final name = TextEditingController(text: client?.nome ?? '');
  final phone = TextEditingController(text: client?.telefone ?? '');
  final neighborhood = TextEditingController(text: client?.bairro ?? '');
  final key = GlobalKey<FormState>();

  return showModalBottomSheet<ClientFormValue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Form(
        key: key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client == null ? 'Cadastrar cliente' : 'Editar cliente',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
                validator: (value) =>
                    (value?.replaceAll(RegExp(r'\D'), '').length ?? 0) < 8
                        ? 'Informe um telefone válido.'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: neighborhood,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Informe o bairro.'
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!(key.currentState?.validate() ?? false)) return;
                    Navigator.of(sheetContext).pop(
                      ClientFormValue(
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                        neighborhood: neighborhood.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<PaymentFormValue?> showPaymentForm(
  BuildContext context, {
  required Parcela installment,
}) {
  final amount = TextEditingController(
    text: installment.restante.toStringAsFixed(2).replaceAll('.', ','),
  );
  final notes = TextEditingController();
  final key = GlobalKey<FormState>();
  // A data parte do vencimento cadastrado da parcela, nao do dia de hoje.
  var date = dateOnly(installment.vencimento);
  var method = 'Pix';

  return showModalBottomSheet<PaymentFormValue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receber parcela ${installment.numero}/${installment.total}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Valor recebido'),
                  validator: (value) {
                    final parsed = _money(value);
                    if (parsed <= 0) return 'Informe um valor maior que zero.';
                    if (parsed > installment.restante + 0.005) {
                      return 'O valor excede o saldo da parcela.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Forma'),
                  items: const [
                    'Pix',
                    'Dinheiro',
                    'Cartão',
                    'Transferência',
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => method = value ?? 'Pix'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data do recebimento'),
                  subtitle: Text(AppFormatters.numericDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      // Datas futuras sao validas: o vencimento da parcela
                      // pode estar a frente do dia de hoje.
                      lastDate: _datePickerLastDate(),
                      helpText: 'Data do recebimento',
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (!(key.currentState?.validate() ?? false)) return;
                      Navigator.of(sheetContext).pop(
                        PaymentFormValue(
                          value: _money(amount.text),
                          date: date,
                          method: method,
                          notes: notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Confirmar recebimento'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<DateTime?> showRenegotiationDate(
  BuildContext context, {
  required Parcela installment,
  DateTime? suggestedDate,
}) {
  final today = dateOnly(DateTime.now());
  final due = dateOnly(suggestedDate ?? installment.vencimento);
  // Abre no vencimento cadastrado; se ele ja passou, cai no dia de hoje para
  // respeitar o piso do seletor.
  final initial = due.isBefore(today) ? today : due;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: today,
    lastDate: _datePickerLastDate(),
    helpText:
        'Parcela ${installment.numero}/${installment.total}: novo vencimento',
  );
}

/// Pergunta se as parcelas seguintes devem acompanhar a nova data.
///
/// Retorna `true` para recalcular as proximas, `false` para manter como estao
/// e `null` quando o usuario dispensa o dialogo.
Future<bool?> confirmShiftFollowingInstallments(
  BuildContext context, {
  required int following,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title:
          const Text('Deseja alterar também as datas das parcelas seguintes?'),
      content: Text(
        following == 1
            ? 'Você escolherá agora a nova data da próxima parcela em aberto. '
                'Parcelas anteriores e já pagas não mudam.'
            : 'Você escolherá, uma por vez, as novas datas das $following '
                'próximas parcelas em aberto. Parcelas anteriores e já pagas '
                'não mudam.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Manter as próximas parcelas'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Alterar as próximas parcelas'),
        ),
      ],
    ),
  );
}

/// Executa uma acao comercial mostrando erro com retry no `ScaffoldMessenger`.
///
/// Retorna `true` quando a operacao terminou sem excecao.
Future<bool> runSalesAction(
  BuildContext context,
  Future<void> Function() operation, {
  String? success,
}) async {
  try {
    await operation();
    if (!context.mounted) return true;
    if (success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    }
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$error'),
        action: SnackBarAction(
          label: 'Tentar novamente',
          onPressed: () => runSalesAction(context, operation, success: success),
        ),
      ),
    );
    return false;
  }
}

Future<void> openWhatsAppCollection({
  required Cliente client,
  Parcela? installment,
}) async {
  final amount = installment?.restante;
  final message = amount == null
      ? 'Olá, ${client.nome}! Tudo bem? Estou entrando em contato sobre suas parcelas.'
      : 'Olá, ${client.nome}! Tudo bem? Sua parcela possui saldo de '
          'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}. '
          'Podemos combinar o pagamento?';
  await openWhatsAppConversation(client: client, message: message);
}

Future<void> openWhatsAppConversation({
  required Cliente client,
  String? message,
}) async {
  final uri = whatsappUri(
    client.telefone,
    message ?? 'Olá, ${client.nome}! Tudo bem?',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const AppException('Não foi possível abrir o WhatsApp.');
  }
}

Future<void> openPhoneDialer(Cliente client) async {
  final uri = phoneDialUri(client.telefone);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const AppException(
        'Não foi possível abrir o aplicativo de telefone.');
  }
}

Uri phoneDialUri(String rawPhone) {
  return Uri(scheme: 'tel', path: rawPhone.replaceAll(RegExp(r'[^\d+]'), ''));
}

Uri whatsappUri(String rawPhone, String message) {
  var phone = rawPhone.replaceAll(RegExp(r'\D'), '');
  if (phone.length == 10 || phone.length == 11) phone = '55$phone';
  return Uri.https('wa.me', '/$phone', {'text': message});
}

double _money(String? value) {
  final raw = (value ?? '').trim().replaceAll(RegExp(r'[^0-9,.]'), '');
  if (raw.isEmpty) return 0;
  final normalized =
      raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
  return double.tryParse(normalized) ?? 0;
}
