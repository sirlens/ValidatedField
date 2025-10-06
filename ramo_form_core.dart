import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ramo_sales/shared/snackbar_zero.dart';

// ============================================================================
// CORE: Resultado de validación genérico
// ============================================================================

class ValidationResult<T> {
  final bool accepted;
  final T validValue;
  final String? errorMessage;

  const ValidationResult({
    required this.accepted,
    required this.validValue,
    this.errorMessage,
  });

  factory ValidationResult.accept(T value) {
    return ValidationResult(accepted: true, validValue: value);
  }

  factory ValidationResult.reject(T fallbackValue, [String? message]) {
    return ValidationResult(
      accepted: false,
      validValue: fallbackValue,
      errorMessage: message,
    );
  }
}

// ============================================================================
// CALLBACKS: Tipos de funciones para validación
// ============================================================================

/// Callback principal de validación
typedef ValidatorCallback<T> = ValidationResult<T> Function(T newValue);

/// Callback para manejar errores de validación
typedef ErrorCallback = void Function(String message);

/// Callback para parsear texto a tipo T
typedef ParserCallback<T> = T Function(String text);

/// Callback para formatear tipo T a String
typedef FormatterCallback<T> = String Function(T value);

/// Callback cuando el campo está vacío
typedef EmptyCallback<T> = void Function();

// ============================================================================
// CONFIG: Configuración del campo validado
// ============================================================================

class ValidatedFieldConfig<T> {
  /// Parser personalizado (null = parser por defecto)
  final ParserCallback<T>? parser;

  /// Formatter personalizado (null = toString())
  final FormatterCallback<T>? formatter;

  /// Manejador de errores personalizado
  final ErrorCallback? onError;

  /// Callback cuando el campo queda vacío
  final EmptyCallback<T>? onEmpty;

  /// Input formatters para el TextField
  final List<TextInputFormatter>? inputFormatters;

  /// Decoración del TextField
  final InputDecoration? decoration;

  /// TextAlign del campo
  final TextAlign textAlign;

  /// Si debe sincronizarse automáticamente con cambios externos
  final bool autoSync;

  /// Si debe mostrar el valor 0 como campo vacío
  final bool showZeroAsEmpty;

  /// Validadores adicionales antes del callback principal
  final List<String? Function(T value)> preValidators;

  const ValidatedFieldConfig({
    this.parser,
    this.formatter,
    this.onError,
    this.onEmpty,
    this.inputFormatters,
    this.decoration,
    this.textAlign = TextAlign.start,
    this.autoSync = true,
    this.showZeroAsEmpty = false,
    this.preValidators = const [],
  });
}

// ============================================================================
// WIDGET: Campo de texto validado genérico
// ============================================================================

class ValidatedField<T> extends StatefulWidget {
  final T value;
  final ValidatorCallback<T> onValidate;
  final ValidatedFieldConfig<T> config;

  const ValidatedField({
    super.key,
    required this.value,
    required this.onValidate,
    this.config = const ValidatedFieldConfig(),
  });

  @override
  State<ValidatedField<T>> createState() => _ValidatedFieldState<T>();
}

class _ValidatedFieldState<T> extends State<ValidatedField<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;
  String _lastValidText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _lastValidText = _controller.text;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ValidatedField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Solo sincronizar si autoSync está habilitado y NO está editando
    if (widget.config.autoSync && !_isEditing && widget.value != oldWidget.value) {
      final formattedValue = _formatValue(widget.value);
      if (_controller.text != formattedValue) {
        _controller.text = formattedValue;
        _lastValidText = formattedValue;
      }
    }
  }

  // ========================================================================
  // HELPERS: Formateo y parseo
  // ========================================================================

  String _formatValue(T value) {
    // Si hay un formatter personalizado, usarlo
    if (widget.config.formatter != null) {
      return widget.config.formatter!(value);
    }

    // Manejar el caso especial de 0
    if (widget.config.showZeroAsEmpty && value == 0) {
      return '';
    }

    return value.toString();
  }

  T _parseValue(String text) {
    // Si hay un parser personalizado, usarlo
    if (widget.config.parser != null) {
      return widget.config.parser!(text);
    }

    // Parser por defecto según el tipo
    if (T == int) {
      return (int.tryParse(text) ?? 0) as T;
    } else if (T == double) {
      return (double.tryParse(text) ?? 0.0) as T;
    } else if (T == String) {
      return text as T;
    }

    throw UnsupportedError('Tipo $T no soportado. Proporciona un parser personalizado.');
  }

  // ========================================================================
  // VALIDATION: Lógica de validación
  // ========================================================================

  void _handleError(String message) {
    if (widget.config.onError != null) {
      widget.config.onError!(message);
    } else {
      // Manejador por defecto: SnackBar
      if (!mounted) return;
      context.showWarningSnackBar(message);
    }
  }

  void _validateAndCommit(String text) {
    // Si está vacío durante la edición, permitirlo temporalmente
    if (text.isEmpty && _isEditing) {
      return;
    }

    final newValue = _parseValue(text);

    // Ejecutar pre-validadores
    for (final preValidator in widget.config.preValidators) {
      final error = preValidator(newValue);
      if (error != null) {
        _handleError(error);
        _restoreLastValid();
        return;
      }
    }

    // Validación principal
    final result = widget.onValidate(newValue);

    if (!result.accepted) {
      if (result.errorMessage != null) {
        _handleError(result.errorMessage!);
      }
      _restoreLastValid();
    } else {
      // Actualizar el último texto válido
      _lastValidText = text;
    }
  }

  void _restoreLastValid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isEditing) {
        _controller.text = _lastValidText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  // ========================================================================
  // FOCUS: Manejo de foco
  // ========================================================================

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Al obtener foco: modo edición
      _isEditing = true;
      _lastValidText = _controller.text;
    } else {
      // Al perder foco: validar y sincronizar
      if (_isEditing) {
        _isEditing = false;

        if (_controller.text.isEmpty) {
          // Campo vacío: ejecutar callback o validar con valor por defecto
          if (widget.config.onEmpty != null) {
            widget.config.onEmpty!();
          } else {
            final result = widget.onValidate(_parseValue('0'));
            if (result.accepted && result.validValue == 0) {
              _controller.text = widget.config.showZeroAsEmpty ? '' : '0';
            }
          }
        } else {
          // Validar el contenido final
          _validateAndCommit(_controller.text);
        }
      }
    }
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: widget.config.decoration ?? const InputDecoration(),
      keyboardType: _getKeyboardType(),
      inputFormatters: widget.config.inputFormatters ?? _getDefaultFormatters(),
      textAlign: widget.config.textAlign,
      onChanged: _validateAndCommit,
      onTapOutside: (_) => _focusNode.unfocus(),
    );
  }

  TextInputType _getKeyboardType() {
    if (T == int) return TextInputType.number;
    if (T == double) return const TextInputType.numberWithOptions(decimal: true);
    return TextInputType.text;
  }

  List<TextInputFormatter> _getDefaultFormatters() {
    if (T == int) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    if (T == double) {
      return [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }
    return [];
  }
}

// ============================================================================
// VALIDATORS: Validadores predefinidos reutilizables
// ============================================================================

class Validators {
  /// Validador de rango numérico
  static String? Function(T) range<T extends num>(T min, T max) {
    return (value) {
      if (value < min || value > max) {
        return 'El valor debe estar entre $min y $max';
      }
      return null;
    };
  }

  /// Validador de mínimo
  static String? Function(T) min<T extends num>(T minValue) {
    return (value) {
      if (value < minValue) {
        return 'El valor mínimo es $minValue';
      }
      return null;
    };
  }

  /// Validador de máximo
  static String? Function(T) max<T extends num>(T maxValue) {
    return (value) {
      if (value > maxValue) {
        return 'El valor máximo es $maxValue';
      }
      return null;
    };
  }

  /// Validador de múltiplo
  static String? Function(int) multipleOf(int factor) {
    return (value) {
      if (value % factor != 0) {
        return 'Debe ser múltiplo de $factor';
      }
      return null;
    };
  }

  /// Validador de longitud de texto
  static String? Function(String) length(int minLength, [int? maxLength]) {
    return (value) {
      if (value.length < minLength) {
        return 'Mínimo $minLength caracteres';
      }
      if (maxLength != null && value.length > maxLength) {
        return 'Máximo $maxLength caracteres';
      }
      return null;
    };
  }

  /// Validador de email
  static String? Function(String) email() {
    return (value) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Email inválido';
      }
      return null;
    };
  }

  /// Validador personalizado
  static String? Function(T) custom<T>(bool Function(T) condition, String errorMessage) {
    return (value) => condition(value) ? null : errorMessage;
  }
}

// ============================================================================
// BUILDER: Constructor fluido para configuración
// ============================================================================

class ValidatedFieldBuilder<T> {
  T? _value;
  ValidatorCallback<T>? _onValidate;
  ParserCallback<T>? _parser;
  FormatterCallback<T>? _formatter;
  ErrorCallback? _onError;
  EmptyCallback<T>? _onEmpty;
  List<TextInputFormatter>? _inputFormatters;
  InputDecoration? _decoration;
  TextAlign _textAlign = TextAlign.start;
  bool _autoSync = true;
  bool _showZeroAsEmpty = false;
  final List<String? Function(T)> _preValidators = [];

  ValidatedFieldBuilder<T> value(T val) {
    _value = val;
    return this;
  }

  ValidatedFieldBuilder<T> onValidate(ValidatorCallback<T> callback) {
    _onValidate = callback;
    return this;
  }

  ValidatedFieldBuilder<T> parser(ParserCallback<T> parser) {
    _parser = parser;
    return this;
  }

  ValidatedFieldBuilder<T> formatter(FormatterCallback<T> formatter) {
    _formatter = formatter;
    return this;
  }

  ValidatedFieldBuilder<T> onError(ErrorCallback callback) {
    _onError = callback;
    return this;
  }

  ValidatedFieldBuilder<T> onEmpty(EmptyCallback<T> callback) {
    _onEmpty = callback;
    return this;
  }

  ValidatedFieldBuilder<T> inputFormatters(List<TextInputFormatter> formatters) {
    _inputFormatters = formatters;
    return this;
  }

  ValidatedFieldBuilder<T> decoration(InputDecoration decoration) {
    _decoration = decoration;
    return this;
  }

  ValidatedFieldBuilder<T> textAlign(TextAlign align) {
    _textAlign = align;
    return this;
  }

  ValidatedFieldBuilder<T> autoSync(bool sync) {
    _autoSync = sync;
    return this;
  }

  ValidatedFieldBuilder<T> showZeroAsEmpty(bool show) {
    _showZeroAsEmpty = show;
    return this;
  }

  ValidatedFieldBuilder<T> addValidator(String? Function(T) validator) {
    _preValidators.add(validator);
    return this;
  }

  ValidatedField<T> build() {
    assert(_value != null, 'Value is required');
    assert(_onValidate != null, 'onValidate callback is required');

    return ValidatedField<T>(
      value: _value as T,
      onValidate: _onValidate!,
      config: ValidatedFieldConfig<T>(
        parser: _parser,
        formatter: _formatter,
        onError: _onError,
        onEmpty: _onEmpty,
        inputFormatters: _inputFormatters,
        decoration: _decoration,
        textAlign: _textAlign,
        autoSync: _autoSync,
        showZeroAsEmpty: _showZeroAsEmpty,
        preValidators: _preValidators,
      ),
    );
  }
}
