# ValidatedField
Un prototipo de un TextField genérico para poder reusar en tu proyectos que gestiona automáticamente el estado, la validación y el parseo de datos.

# Núcleo de Formularios Genéricos (`RamoFormCore`)

Este paquete proporciona un sistema de campos de formulario genéricos y autovalidados (`ValidatedField<T>`) que simplifica la sincronización de estado, el parseo de tipos de datos y la gestión de validaciones en Flutter.

## 1\. Instalación y Uso

Aun no existe paquete, pero cuando exista sería algo así (`ramo_form_core`), solo necesitas una línea para acceder a todas las herramientas, por ahora sólo bastaría con usar el fichero e importarlo:

```dart
import 'package:ramo_form_core/ramo_form_core.dart';
// Ahora tienes acceso a ValidatedField, Validators y ValidationResult.
```

## 2\. Uso Básico de `ValidatedField<T>`

`ValidatedField<T>` reemplaza al `TextFormField` estándar, manejando tipos de datos (`T`) y aplicando lógica de validación al perder el foco.

### Ejemplo: Campo de Entero

```dart
class MyFormWidget extends StatefulWidget {
  const MyFormWidget({super.key});
  
  @override
  State<MyFormWidget> createState() => _MyFormWidgetState();
}

class _MyFormWidgetState extends State<MyFormWidget> {
  // 1. Estado para el campo (entero)
  int _age = 25; 

  @override
  Widget build(BuildContext context) {
    return ValidatedField<int>( // ⬅️ Definición del tipo T=int
      value: _age, 
      
      // 2. Lógica de validación principal:
      onValidate: (newAge) {
        if (newAge < 18) {
          // Si es menor de edad, rechazar y mantener el valor actual (_age)
          return ValidationResult.reject(_age, 'Debe ser mayor de 18 años.');
        }
        // Si es válido, actualizar el estado
        setState(() => _age = newAge); 
        return ValidationResult.accept(newAge);
      },
      
      // 3. Configuración opcional
      config: ValidatedFieldConfig<int>(
        decoration: const InputDecoration(labelText: 'Edad'),
        // El resto usa el parser y formatter por defecto (int.tryParse y toString)
      ),
    );
  }
}
```

-----

## 3\. Configuración Avanzada con `ValidatedFieldBuilder`

Se recomienda usar el patrón **Builder** para configurar campos complejos con múltiples validadores y *callbacks*, lo que mejora la legibilidad.

### Ejemplo: Campo de Doble con Múltiples Reglas

```dart
// Usando el Builder para configurar todas las opciones de forma fluida
ValidatedField<double>(
  value: _price,
  onValidate: (newPrice) {
    // Lógica principal: siempre acepta el valor validado
    setState(() => _price = newPrice);
    return ValidationResult.accept(newPrice);
  },
  config: ValidatedFieldConfig(
    // Personalizar cómo se muestra y se parsea
    formatter: (value) => value.toStringAsFixed(2), 
    
    // Aplicar una lista de validadores estáticos
    preValidators: [
      Validators.min(1.00),         // Mínimo 1.00
      Validators.range(1.00, 1000.00), // Rango de 1 a 1000
    ],
    
    // Opciones de UI y comportamiento
    textAlign: TextAlign.right,
    decoration: const InputDecoration(labelText: 'Precio (Min S/1.00)'),
    
    // Deshabilitar la sincronización automática si el valor cambia externamente
    autoSync: false,
  ),
)
```

-----

## 4\. Referencia de Componentes Clave

| Clase/Función | Propósito | Uso Común |
| :--- | :--- | :--- |
| **`ValidatedField<T>`** | Widget principal. Maneja el control de texto, foco, parseo y la validación automática al perder foco. | `ValidatedField<String>(...)` |
| **`ValidationResult<T>`** | Objeto retornado por `onValidate`. Indica si el valor fue **aceptado** y cuál es el valor final. | `return ValidationResult.reject(v, 'Error');` |
| **`ValidatedFieldConfig<T>`** | Contenedor de configuración avanzada (parsers, formatters, decoración y callbacks de error). | Usado en la propiedad `config:` de `ValidatedField`. |
| **`Validators`** | Clase estática que ofrece funciones de validación reutilizables. Se usa en `config.preValidators`. | `Validators.email()`, `Validators.range(0, 100)` |
| **`ValidatedFieldBuilder<T>`** | Patrón para construir el widget con todos sus parámetros de forma secuencial y legible. | `ValidatedFieldBuilder<int>().value(0).build()` |
