import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ajustes/acerca_screen.dart';
import '../features/ajustes/ajustes_screen.dart';
import '../features/ajustes/categorias_gasto_screen.dart';
import '../features/ajustes/respaldo_screen.dart';
import '../features/catalogo/categorias_screen.dart';
import '../features/catalogo/menu_precios_screen.dart';
import '../features/catalogo/modificadores_screen.dart';
import '../features/catalogo/producto_form_screen.dart';
import '../features/catalogo/promociones_screen.dart';
import '../features/cobro/cobrar_screen.dart';
import '../features/cuentas/cuenta_detalle_screen.dart';
import '../features/cuentas/cuentas_screen.dart';
import '../features/inventario/conteo_screen.dart';
import '../features/inventario/gastos_screen.dart';
import '../features/inventario/insumo_form_screen.dart';
import '../features/inventario/inventario_screen.dart';
import '../features/inventario/proveedores_screen.dart';
import '../features/pedido/confirmar_pedido_screen.dart';
import '../features/pedido/nuevo_pedido_screen.dart';
import '../features/reportes/reportes_screen.dart';
import '../features/turno/turno_screen.dart';
import '../widgets/shell_scaffold.dart';

abstract final class Routes {
  static const cuentas = '/cuentas';
  static const menu = '/menu';
  static const confirmar = '/menu/confirmar';
  static const inventario = '/inventario';
  static const reportes = '/reportes';
  static const turno = '/turno';
  static const catalogo = '/catalogo';
  static const nuevoProducto = '/catalogo/producto';
  static const categorias = '/catalogo/categorias';
  static const modificadores = '/catalogo/modificadores';
  static const promociones = '/catalogo/promociones';
  static const nuevoInsumo = '/insumo';
  static const proveedores = '/proveedores';
  static const conteo = '/conteo';
  static const gastos = '/gastos';
  static const ajustes = '/ajustes';
  static const respaldo = '/ajustes/respaldo';
  static const categoriasGasto = '/ajustes/categorias-gasto';
  static const acerca = '/ajustes/acerca';

  static String cobrar(String orderId) => '/cobrar/$orderId';
  static String cuenta(String orderId) => '/cuenta/$orderId';
  static String producto(String productId) => '/catalogo/producto/$productId';
  static String insumo(String itemId) => '/insumo/$itemId';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRoute _full(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) => GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (_, s) => build(s),
      routes: routes,
    );

/// Mapa de navegación:
///
/// Shell con barra inferior (conserva estado por pestaña)
///  ├─ /cuentas  ·  /menu (+ /menu/confirmar)  ·  /inventario  ·  /reportes
/// Pantallas completas
///  ├─ /cuenta/:id, /cobrar/:id, /turno
///  ├─ /catalogo (+ producto, categorías, modificadores, promociones)
///  ├─ /insumo, /proveedores, /conteo, /gastos
///  └─ /ajustes (+ respaldo, categorías de gasto, acerca de)
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.cuentas,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.cuentas, builder: (_, __) => const CuentasScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.menu,
              builder: (_, __) => const NuevoPedidoScreen(),
              routes: [
                GoRoute(path: 'confirmar', builder: (_, __) => const ConfirmarPedidoScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.inventario, builder: (_, __) => const InventarioScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.reportes, builder: (_, __) => const ReportesScreen()),
          ]),
        ],
      ),
      _full('/cobrar/:orderId', (s) => CobrarScreen(orderId: s.pathParameters['orderId']!)),
      _full('/cuenta/:orderId', (s) => CuentaDetalleScreen(orderId: s.pathParameters['orderId']!)),
      _full(Routes.turno, (_) => const TurnoScreen()),
      _full(Routes.catalogo, (_) => const MenuPreciosScreen(), routes: [
        GoRoute(
          path: 'producto',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ProductoFormScreen(),
          routes: [
            GoRoute(
              path: ':productId',
              parentNavigatorKey: _rootKey,
              builder: (_, s) => ProductoFormScreen(productId: s.pathParameters['productId']),
            ),
          ],
        ),
        GoRoute(path: 'categorias', parentNavigatorKey: _rootKey, builder: (_, __) => const CategoriasScreen()),
        GoRoute(path: 'modificadores', parentNavigatorKey: _rootKey, builder: (_, __) => const ModificadoresScreen()),
        GoRoute(path: 'promociones', parentNavigatorKey: _rootKey, builder: (_, __) => const PromocionesScreen()),
      ]),
      _full(Routes.nuevoInsumo, (s) => InsumoFormScreen(barcode: s.uri.queryParameters['barcode']), routes: [
        GoRoute(
          path: ':itemId',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => InsumoFormScreen(itemId: s.pathParameters['itemId']),
        ),
      ]),
      _full(Routes.proveedores, (_) => const ProveedoresScreen()),
      _full(Routes.conteo, (_) => const ConteoScreen()),
      _full(Routes.gastos, (_) => const GastosScreen()),
      _full(Routes.ajustes, (_) => const AjustesScreen(), routes: [
        GoRoute(path: 'respaldo', parentNavigatorKey: _rootKey, builder: (_, __) => const RespaldoScreen()),
        GoRoute(
            path: 'categorias-gasto', parentNavigatorKey: _rootKey, builder: (_, __) => const CategoriasGastoScreen()),
        GoRoute(path: 'acerca', parentNavigatorKey: _rootKey, builder: (_, __) => const AcercaScreen()),
      ]),
    ],
  );
}
