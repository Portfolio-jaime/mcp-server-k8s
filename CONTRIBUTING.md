# 🤝 Guía de Contribución

¡Gracias por tu interés en contribuir al Kubernetes MCP Server! Esta guía te ayudará a empezar.

## 🚀 Cómo Contribuir

### 1. Fork y Clone
```bash
# Fork el repositorio en GitHub
# Luego clona tu fork
git clone https://github.com/tu-usuario/k8s-mcp-server.git
cd k8s-mcp-server
```

### 2. Configurar Entorno de Desarrollo
```bash
# Instalar dependencias
npm install

# Abrir en DevContainer (recomendado)
# En VS Code: Cmd+Shift+P → "Dev Containers: Reopen in Container"
```

### 3. Crear Branch para tu Feature
```bash
git checkout -b feature/mi-nueva-funcionalidad
```

### 4. Hacer Cambios
- Escribir código siguiendo las convenciones del proyecto
- Agregar tests para nueva funcionalidad
- Actualizar documentación si es necesario

### 5. Verificar Cambios
```bash
# Ejecutar tests
npm test

# Verificar linting
npm run lint

# Verificar tipos
npm run type-check

# Ejecutar todos los checks
npm run validate
```

### 6. Commit y Push
```bash
git add .
git commit -m "feat: agregar nueva funcionalidad X"
git push origin feature/mi-nueva-funcionalidad
```

### 7. Crear Pull Request
- Ve a GitHub y crea un Pull Request
- Describe los cambios claramente
- Incluye tests y documentación

## 📋 Convenciones

### Commits
Usamos [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` nueva funcionalidad
- `fix:` corrección de bug
- `docs:` cambios en documentación
- `test:` agregar o modificar tests
- `refactor:` refactoring de código
- `chore:` tareas de mantenimiento

### Código
- TypeScript estricto
- ESLint para linting
- Prettier para formato
- Tests con Vitest

### Documentación
- README.md actualizado
- Comentarios en código complejo
- Ejemplos de uso
- Documentación en `/docs`

## 🧪 Testing

### Ejecutar Tests
```bash
# Tests unitarios
npm test

# Tests con coverage
npm run test:coverage

# Tests del servidor MCP
./scripts/test-mcp.sh

# Tests del servidor HTTPS
./scripts/test-mcp-https.sh
```

### Escribir Tests
- Tests unitarios en `src/**/__tests__/`
- Tests de integración en `src/__tests__/`
- Usar Vitest para testing
- Cobertura mínima del 80%

## 📁 Estructura del Proyecto

```
src/
├── index.ts                 # Servidor MCP principal
├── https-server.ts         # Servidor HTTPS
├── services/               # Servicios de negocio
│   ├── kubernetes.ts       # Interacción con Kubernetes
│   ├── helm.ts            # Interacción con Helm
│   └── version-analyzer.ts # Análisis de versiones
└── __tests__/             # Tests de integración
```

## 🐛 Reportar Bugs

Cuando reportes un bug, incluye:
- Descripción clara del problema
- Pasos para reproducir
- Comportamiento esperado vs actual
- Versiones (Node.js, kubectl, helm)
- Logs relevantes

## 💡 Solicitar Features

Para solicitar nuevas funcionalidades:
- Describe el caso de uso
- Explica por qué es útil
- Proporciona ejemplos
- Considera la implementación

## 🔧 Configuración de Desarrollo

### DevContainer (Recomendado)
El proyecto incluye un DevContainer con todo configurado:
- Node.js + TypeScript
- kubectl, helm, minikube
- Extensions de VS Code
- Docker-in-Docker

### Local
Si prefieres desarrollo local:
```bash
# Instalar dependencias
npm install

# Instalar herramientas de Kubernetes
# kubectl: https://kubernetes.io/docs/tasks/tools/
# helm: https://helm.sh/docs/intro/install/
# minikube: https://minikube.sigs.k8s.io/docs/start/
```

## 🎯 Tipos de Contribuciones

### 🐛 Bug Fixes
- Correcciones de errores
- Mejoras de estabilidad
- Fixes de compatibilidad

### ✨ Nuevas Features
- Nuevas herramientas MCP
- Mejoras de funcionalidad existente
- Optimizaciones de rendimiento

### 📖 Documentación
- Guías y tutoriales
- Ejemplos de uso
- API documentation
- README improvements

### 🧪 Testing
- Tests unitarios
- Tests de integración
- Test automation
- Performance tests

### 🔧 DevOps
- CI/CD improvements
- Docker optimizations
- Scripts de automatización
- Monitoring y logging

## 📞 Obtener Ayuda

- **GitHub Issues**: Para bugs y feature requests
- **GitHub Discussions**: Para preguntas generales
- **Documentación**: En `/docs`

## 🏆 Reconocimientos

Los contribuidores aparecerán en:
- README.md
- CONTRIBUTORS.md
- Release notes

¡Gracias por contribuir! 🎉