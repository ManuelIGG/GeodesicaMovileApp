-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 18-02-2026 a las 21:57:28
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.1.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `storetecnology2`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `actividades`
--

CREATE TABLE `actividades` (
  `id_actividad` int(11) NOT NULL,
  `tipo_actividad` varchar(50) NOT NULL COMMENT 'Llamada, Email, Reunión, Presentación',
  `fecha_programada` datetime DEFAULT NULL,
  `estado` varchar(50) NOT NULL DEFAULT 'Pendiente' COMMENT 'Pendiente, Completada, Cancelada',
  `notas` text DEFAULT NULL,
  `id_usuario_asignado` int(11) NOT NULL COMMENT 'Usuario responsable de la actividad',
  `id_cliente` int(11) DEFAULT NULL COMMENT 'Cliente relacionado (opcional)',
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `actividades`
--

INSERT INTO `actividades` (`id_actividad`, `tipo_actividad`, `fecha_programada`, `estado`, `notas`, `id_usuario_asignado`, `id_cliente`, `fecha_creacion`) VALUES
(9, 'Llamada', '2025-10-22 18:26:00', 'Pendiente', 'dssd', 1, 19, '2025-10-20 23:13:13'),
(10, 'Llamada', '2025-10-21 23:16:00', 'En Progreso', 'l', 1, 17, '2025-10-20 23:17:08');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `casos_soporte`
--

CREATE TABLE `casos_soporte` (
  `id_caso` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL COMMENT 'FK a tabla usuario',
  `asunto` varchar(200) NOT NULL,
  `descripcion` text NOT NULL,
  `prioridad` varchar(20) DEFAULT 'Media' COMMENT 'Alta, Media, Baja',
  `estado` varchar(50) NOT NULL DEFAULT 'Abierto' COMMENT 'Abierto, En proceso, Resuelto, Cerrado',
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp(),
  `fecha_resolucion` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `casos_soporte`
--

INSERT INTO `casos_soporte` (`id_caso`, `id_cliente`, `asunto`, `descripcion`, `prioridad`, `estado`, `fecha_creacion`, `fecha_resolucion`) VALUES
(18, 19, 'PQR - Cliente 19', 'No se ve el producto', 'Alta', 'Resuelto', '2025-10-20 21:44:56', '2025-10-21 08:29:00'),
(19, 17, 'PQR - Cliente 17', 'Tengo problemas con mis compras', 'Baja', 'Resuelto', '2025-10-20 22:23:28', '2025-10-21 08:28:00'),
(24, 19, 'PQR SOPORTE_TECNICO - Prioridad Baja', 'Tengo problemas con la visualización de productos', 'Baja', 'Abierto', '2025-11-04 19:35:47', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `compra`
--

CREATE TABLE `compra` (
  `idCompra` int(11) NOT NULL,
  `idProveedor` int(11) NOT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  `subtotal` decimal(10,2) NOT NULL DEFAULT 0.00,
  `valor_retefuente` decimal(10,2) DEFAULT 0.00,
  `total_pagado` decimal(10,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `compra`
--

INSERT INTO `compra` (`idCompra`, `idProveedor`, `fecha`, `subtotal`, `valor_retefuente`, `total_pagado`) VALUES
(36, 7, '2025-10-13 01:26:44', 12500000.00, 281250.00, 12218750.00),
(37, 8, '2025-10-21 00:55:29', 144000.00, 3600.00, 140400.00),
(38, 8, '2025-11-11 01:12:09', 144000.00, 3600.00, 140400.00),
(39, 7, '2025-11-11 01:12:24', 30000000.00, 675000.00, 29325000.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallepedido`
--

CREATE TABLE `detallepedido` (
  `idDetallePedido` int(11) NOT NULL,
  `idPedido` int(11) NOT NULL,
  `idProducto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 1,
  `precio_unitario` decimal(10,2) NOT NULL COMMENT 'Precio del producto al momento del pedido',
  `descuento_unitario` decimal(10,2) DEFAULT 0.00 COMMENT 'Descuento aplicado por unidad',
  `impuesto_unitario` decimal(10,2) DEFAULT 0.00 COMMENT 'Impuesto aplicado por unidad',
  `subtotal_linea` decimal(10,2) NOT NULL COMMENT 'Subtotal de la línea (cantidad * precio_unitario)',
  `total_linea` decimal(10,2) NOT NULL COMMENT 'Total final de la línea con descuentos e impuestos'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `detallepedido`
--

INSERT INTO `detallepedido` (`idDetallePedido`, `idPedido`, `idProducto`, `cantidad`, `precio_unitario`, `descuento_unitario`, `impuesto_unitario`, `subtotal_linea`, `total_linea`) VALUES
(98, 71, 19, 1, 2500000.00, 0.00, 475000.00, 2500000.00, 2975000.00),
(99, 71, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(100, 72, 19, 2, 2500000.00, 0.00, 475000.00, 5000000.00, 5950000.00),
(101, 72, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(102, 73, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(104, 75, 20, 3, 12000.00, 1200.00, 2052.00, 36000.00, 38556.00),
(105, 76, 20, 3, 12000.00, 1200.00, 2052.00, 36000.00, 38556.00),
(106, 76, 19, 2, 2500000.00, 0.00, 475000.00, 5000000.00, 5950000.00),
(107, 77, 19, 2, 2500000.00, 0.00, 475000.00, 5000000.00, 5950000.00),
(108, 77, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(109, 78, 19, 1, 2500000.00, 0.00, 475000.00, 2500000.00, 2975000.00),
(110, 78, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(111, 79, 20, 2, 12000.00, 0.00, 2280.00, 24000.00, 28560.00),
(112, 79, 19, 1, 2500000.00, 0.00, 475000.00, 2500000.00, 2975000.00),
(113, 80, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(114, 80, 19, 1, 2500000.00, 0.00, 475000.00, 2500000.00, 2975000.00),
(115, 81, 20, 1, 12000.00, 0.00, 2280.00, 12000.00, 14280.00),
(116, 81, 19, 1, 2500000.00, 0.00, 475000.00, 2500000.00, 2975000.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_compra`
--

CREATE TABLE `detalle_compra` (
  `idDetalleCompra` int(11) NOT NULL,
  `idCompra` int(11) NOT NULL,
  `idProducto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 1,
  `precio_unitario` decimal(10,2) NOT NULL,
  `subtotal_linea` decimal(10,2) NOT NULL COMMENT 'cantidad * precio_unitario'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `detalle_compra`
--

INSERT INTO `detalle_compra` (`idDetalleCompra`, `idCompra`, `idProducto`, `cantidad`, `precio_unitario`, `subtotal_linea`) VALUES
(63, 36, 19, 5, 2500000.00, 12500000.00),
(64, 37, 20, 12, 12000.00, 144000.00),
(65, 38, 20, 12, 12000.00, 144000.00),
(66, 39, 19, 12, 2500000.00, 30000000.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `formaspago`
--

CREATE TABLE `formaspago` (
  `idFormaPago` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` varchar(200) DEFAULT NULL,
  `activo` tinyint(1) DEFAULT 1,
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `formaspago`
--

INSERT INTO `formaspago` (`idFormaPago`, `nombre`, `descripcion`, `activo`, `fecha_creacion`) VALUES
(1, 'Mastercard', 'Tarjeta de crédito Mastercard', 1, '2025-08-14 21:00:00'),
(4, 'PayPal', 'Plataforma de pagos PayPal', 1, '2025-08-14 21:00:00'),
(7, 'Efectivo', 'Pago en efectivo', 1, '2025-08-14 21:00:00'),
(8, 'Transferencia Bancaria', 'Transferencia bancaria directa', 1, '2025-08-14 21:00:00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `gastos`
--

CREATE TABLE `gastos` (
  `idGasto` int(11) NOT NULL,
  `idProducto` int(11) NOT NULL,
  `descripcion` varchar(200) NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `fecha` timestamp NOT NULL DEFAULT current_timestamp(),
  `categoria` varchar(100) DEFAULT 'Mantener'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `gastos`
--

INSERT INTO `gastos` (`idGasto`, `idProducto`, `descripcion`, `monto`, `fecha`, `categoria`) VALUES
(23, 19, 'Darle publicidad al producto', 10000.00, '2025-10-13 01:27:13', 'Mantener'),
(24, 19, 'Mantener', 10000.00, '2025-10-13 01:27:42', 'publicidad'),
(26, 20, 'Darle publicidad al producto', 12000.00, '2025-10-21 00:57:05', 'Mantener');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `interacciones`
--

CREATE TABLE `interacciones` (
  `id_interaccion` int(11) NOT NULL,
  `id_cliente` int(11) DEFAULT NULL COMMENT 'FK a tabla usuario',
  `tipo_interaccion` varchar(50) NOT NULL COMMENT 'Llamada, Email, Reunión, Chat, etc.',
  `fecha_interaccion` datetime NOT NULL,
  `descripcion` text DEFAULT NULL,
  `id_usuario` int(11) DEFAULT NULL COMMENT 'Usuario que realizó la interacción',
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `interacciones`
--

INSERT INTO `interacciones` (`id_interaccion`, `id_cliente`, `tipo_interaccion`, `fecha_interaccion`, `descripcion`, `id_usuario`, `fecha_creacion`) VALUES
(77, 17, 'Mensaje Automático', '2025-10-20 22:29:20', 'Gracias, ya se ha resuelto tu petición.', 1, '2025-10-20 22:29:20'),
(78, 19, 'Chat', '2025-10-30 08:30:00', 'Gracias, ya se ha resuelto tu petición.', 1, '2025-10-20 22:30:01'),
(81, 19, 'Chat', '2025-11-03 20:31:53', 'hola', NULL, '2025-11-03 20:31:53'),
(84, 19, 'Chat', '2025-11-05 05:35:00', 'Asistente IA: Estimado Cliente 19, lamento escuchar que estás experimentando problemas con la visualización de productos en nuestra plataforma. Queremos asegurarnos de que tu experiencia sea satisfactoria. Para res...', 1, '2025-11-04 19:35:53');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `oportunidades`
--

CREATE TABLE `oportunidades` (
  `id_oportunidad` int(11) NOT NULL,
  `id_cliente` int(11) DEFAULT NULL COMMENT 'FK a tabla usuario',
  `titulo` varchar(200) NOT NULL,
  `valor_estimado` decimal(10,2) NOT NULL DEFAULT 0.00,
  `etapa` varchar(50) NOT NULL DEFAULT 'Prospecto' COMMENT 'Prospecto, Calificación, Propuesta, Negociación, Cierre',
  `probabilidad` int(11) NOT NULL DEFAULT 0 COMMENT 'Porcentaje 0-100',
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `oportunidades`
--

INSERT INTO `oportunidades` (`id_oportunidad`, `id_cliente`, `titulo`, `valor_estimado`, `etapa`, `probabilidad`, `fecha_creacion`) VALUES
(31, 17, 'Oportunidad - Cliente 17', 10.00, 'Prospecto', 100, '2025-10-20 22:23:08'),
(32, 19, 'ASSS', 21.00, 'Calificación', 75, '2025-10-22 23:21:02'),
(33, 21, 'Oportunidad - Cliente 21', 10.00, 'Prospecto', 100, '2025-10-21 01:01:53');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos`
--

CREATE TABLE `pagos` (
  `idPago` int(11) NOT NULL,
  `NombrePersona` varchar(100) NOT NULL,
  `Direccion` varchar(255) NOT NULL,
  `idFormaPago` int(11) NOT NULL,
  `Telefono` varchar(20) DEFAULT NULL,
  `correo_electronico` varchar(100) NOT NULL,
  `monto_subtotal` decimal(10,2) NOT NULL COMMENT 'Monto antes de impuestos y descuentos',
  `descuentos` decimal(10,2) DEFAULT 0.00 COMMENT 'Monto total de descuentos aplicados',
  `impuestos` decimal(10,2) DEFAULT 0.00 COMMENT 'Monto total de impuestos (IVA, etc.)',
  `monto_total` decimal(10,2) NOT NULL COMMENT 'Monto final a pagar (subtotal - descuentos + impuestos)',
  `fecha_pago` timestamp NULL DEFAULT current_timestamp(),
  `estado_pago` varchar(50) NOT NULL DEFAULT 'realizado',
  `idUsuario` int(11) DEFAULT NULL,
  `idPedido` int(11) DEFAULT NULL,
  `referencia_pago` varchar(100) DEFAULT NULL COMMENT 'Referencia del pago en la plataforma externa',
  `notas_pago` text DEFAULT NULL COMMENT 'Notas adicionales sobre el pago'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `pagos`
--

INSERT INTO `pagos` (`idPago`, `NombrePersona`, `Direccion`, `idFormaPago`, `Telefono`, `correo_electronico`, `monto_subtotal`, `descuentos`, `impuestos`, `monto_total`, `fecha_pago`, `estado_pago`, `idUsuario`, `idPedido`, `referencia_pago`, `notas_pago`) VALUES
(70, 'Juan Manuel Gonzales Gomes', 'Calle 14 No 14-25', 8, '+573022762284', 'JuanManuel@gmail.com', 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-10-21 01:24:29', 'realizado', 21, 71, 'TRANSFER-2025-000071-1761009869226', 'Método de pago: transfer'),
(71, 'Juan Manuel Gonzales Gomes', 'Calle 14 No 14-25', 4, '+573022762284', 'JuanManuel@gmail.com', 5012000.00, 751800.00, 809438.00, 5084638.00, '2025-10-21 01:28:20', 'realizado', 21, 72, 'PAYPAL-2025-000072-1761010100224', 'Método de pago: paypal'),
(72, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'martas.garcias@email.com', 12000.00, 0.00, 2280.00, 29280.00, '2025-11-10 23:16:12', 'realizado', 19, 73, 'TRANSFER-2025-000073-1762816572836', 'Método de pago: transfer'),
(74, 'Marta García Milenas', 'Calle 14 No 10-13', 4, '+573175527289', 'herrerbrayandavid@gmail.com', 36000.00, 3600.00, 6156.00, 57156.00, '2025-11-11 01:05:53', 'realizado', 19, 75, 'PAYPAL-2025-000075-1762823153095', 'Método de pago: paypal'),
(75, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'herrerbrayandavid@gmail.com', 5036000.00, 759000.00, 812732.60, 5108332.60, '2025-11-11 01:13:01', 'realizado', 19, 76, 'TRANSFER-2025-000076-1762823581138', 'Método de pago: transfer'),
(76, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'herrerbrayandavid@gmail.com', 5012000.00, 751800.00, 809438.00, 5084638.00, '2025-11-11 01:30:20', 'realizado', 19, 77, 'TRANSFER-2025-000077-1762824620981', 'Método de pago: transfer'),
(77, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'herrerbrayandavid@gmail.com', 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:32:13', 'realizado', 19, 78, 'TRANSFER-2025-000078-1762824733593', 'Método de pago: transfer'),
(78, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'herrerbrayandavid@gmail.com', 2524000.00, 378600.00, 407626.00, 2568026.00, '2025-11-11 01:35:09', 'realizado', 19, 79, 'TRANSFER-2025-000079-1762824909427', 'Método de pago: transfer'),
(79, 'Marta García Milenas', 'Calle 14 No 10-13', 8, '+573175527289', 'herrerbrayandavid@gmail.com', 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:35:54', 'realizado', 19, 80, 'TRANSFER-2025-000080-1762824954828', 'Método de pago: transfer'),
(80, 'Marta García Milenas', 'Calle 14 No 10-13', 7, '+573175527289', 'herrerbrayandavid@gmail.com', 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:38:20', 'realizado', 19, 81, 'CASH-2025-000081-1762825100014', 'Método de pago: cash - Pago contra entrega');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `idPedido` int(11) NOT NULL,
  `estado` varchar(50) NOT NULL DEFAULT 'pendiente',
  `infopersona` varchar(200) NOT NULL,
  `correo_electronico` varchar(100) NOT NULL,
  `Direccion` varchar(255) NOT NULL,
  `nombresProductos` text NOT NULL,
  `fecha_pedido` timestamp NULL DEFAULT current_timestamp(),
  `fecha_actualizacion` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `subtotal` decimal(10,2) DEFAULT 0.00 COMMENT 'Total antes de impuestos y descuentos',
  `descuentos_totales` decimal(10,2) DEFAULT 0.00 COMMENT 'Descuentos aplicados al pedido',
  `impuestos_totales` decimal(10,2) DEFAULT 0.00 COMMENT 'Impuestos aplicados al pedido',
  `total` decimal(10,2) DEFAULT 0.00 COMMENT 'Total final del pedido',
  `idUsuario` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `pedidos`
--

INSERT INTO `pedidos` (`idPedido`, `estado`, `infopersona`, `correo_electronico`, `Direccion`, `nombresProductos`, `fecha_pedido`, `fecha_actualizacion`, `subtotal`, `descuentos_totales`, `impuestos_totales`, `total`, `idUsuario`) VALUES
(71, 'enviado', 'Juan Manuel Gonzales Gomes - CC: 1074657888', 'JuanManuel@gmail.com', 'Calle 14 No 14-25', 'Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (1), AirPods Pro (1)', '2025-10-21 01:24:29', '2025-11-10 23:26:01', 2512000.00, 376800.00, 405688.00, 2555888.00, 21),
(72, 'pagado', 'Juan Manuel Gonzales Gomes - CC: 1074657888', 'JuanManuel@gmail.com', 'Calle 14 No 14-25', 'Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (2), AirPods Pro (1)', '2025-10-21 01:28:20', '2025-10-21 01:28:20', 5012000.00, 751800.00, 809438.00, 5084638.00, 21),
(73, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (1)', '2025-11-10 23:16:12', '2025-11-11 00:42:50', 12000.00, 0.00, 2280.00, 29280.00, 19),
(75, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (3)', '2025-11-11 01:05:53', '2025-11-11 01:05:53', 36000.00, 3600.00, 6156.00, 57156.00, 19),
(76, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (3), Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (2)', '2025-11-11 01:13:01', '2025-11-11 01:13:01', 5036000.00, 759000.00, 812732.60, 5108332.60, 19),
(77, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (2), AirPods Pro (1)', '2025-11-11 01:30:20', '2025-11-11 01:30:20', 5012000.00, 751800.00, 809438.00, 5084638.00, 19),
(78, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (1), AirPods Pro (1)', '2025-11-11 01:32:13', '2025-11-11 01:32:13', 2512000.00, 376800.00, 405688.00, 2555888.00, 19),
(79, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (2), Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (1)', '2025-11-11 01:35:09', '2025-11-11 01:35:09', 2524000.00, 378600.00, 407626.00, 2568026.00, 19),
(80, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (1), Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (1)', '2025-11-11 01:35:54', '2025-11-11 01:35:54', 2512000.00, 376800.00, 405688.00, 2555888.00, 19),
(81, 'pagado', 'Marta García Milenas - CC: 1096063622', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', 'AirPods Pro (1), Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3 (1)', '2025-11-11 01:38:19', '2025-11-11 01:38:20', 2512000.00, 376800.00, 405688.00, 2555888.00, 19);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto`
--

CREATE TABLE `producto` (
  `idProducto` int(11) NOT NULL,
  `nombreProducto` varchar(100) NOT NULL,
  `imagen` varchar(100) NOT NULL,
  `valor` decimal(10,2) NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 0,
  `informacion` text DEFAULT NULL,
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp(),
  `activo` tinyint(1) DEFAULT 1,
  `porcentaje_impuesto` decimal(5,2) DEFAULT 19.00 COMMENT 'Porcentaje de IVA aplicable al producto',
  `precio_costo` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Costo del producto para la empresa',
  `idProveedor` int(11) DEFAULT NULL,
  `porcentaje_retefuente` decimal(5,2) DEFAULT 0.00 COMMENT 'ReteFuente si aplica al producto'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `producto`
--

INSERT INTO `producto` (`idProducto`, `nombreProducto`, `imagen`, `valor`, `cantidad`, `informacion`, `fecha_creacion`, `activo`, `porcentaje_impuesto`, `precio_costo`, `idProveedor`, `porcentaje_retefuente`) VALUES
(19, 'Portatil HP Intel Core i5 12450H RAM 8 GB 512 GB SSD IdeaPad Slim 3', 'HPNotebook 14.jpg', 2500000.00, 4, 'Muy buen producto recomendable', '2025-10-13 00:54:59', 1, 19.00, 2500000.00, 7, 2.25),
(20, 'AirPods Pro', 'AirPods_Pro.png', 12000.00, 3, 'Exelentes audifonos con capacidad de aislamiento grande', '2025-10-21 00:48:18', 1, NULL, 12000.00, 8, 2.50);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedor`
--

CREATE TABLE `proveedor` (
  `idProveedor` int(11) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `nit` varchar(50) NOT NULL,
  `direccion` varchar(200) DEFAULT NULL,
  `telefono` varchar(50) DEFAULT NULL,
  `correo` varchar(100) DEFAULT NULL,
  `porcentaje_retefuente` decimal(5,2) DEFAULT 0.00 COMMENT 'Porcentaje de retefuente aplicable a este proveedor'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proveedor`
--

INSERT INTO `proveedor` (`idProveedor`, `nombre`, `nit`, `direccion`, `telefono`, `correo`, `porcentaje_retefuente`) VALUES
(7, 'TigerRollV3', '109606677-7', 'Calle 14 No 10-13', '+573022762284', 'TigerRollV@gmail.com', 2.25),
(8, 'TEC-FAST', '1096063688', 'Calle 14 No 10-15', '+573022478278', 'TEC@gmail.com', 2.50);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

CREATE TABLE `usuario` (
  `idUsuario` int(11) NOT NULL,
  `cedula` varchar(20) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `correo` text NOT NULL,
  `direccion` text NOT NULL,
  `telefono` text NOT NULL,
  `password` varchar(255) NOT NULL,
  `rol` varchar(50) NOT NULL,
  `fecha_creacion` timestamp NULL DEFAULT current_timestamp(),
  `activo` tinyint(1) DEFAULT 1,
  `empresa_trabaja` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`idUsuario`, `cedula`, `nombre`, `correo`, `direccion`, `telefono`, `password`, `rol`, `fecha_creacion`, `activo`, `empresa_trabaja`) VALUES
(1, '123456755', 'Juan Pérez', 'JuanPerez@gmail.com', 'Calle 14 No 10-13', '+573175527281', 'Juan0', 'crm', '2025-10-20 08:39:53', 1, ''),
(5, '1096063633', 'Brayan David Herrera Barajas', 'bherrerabarajs@gmail.com', 'Calle 14 No 10-13', '+573175527281', 'Laurayluis87', 'admin', '2025-08-16 16:40:50', 1, ''),
(17, '1096063644', 'Juan Manuel Gomez', 'Juan@gmail.com', 'Calle 14 No 30-25', '3022762259', 'Juan', 'cliente', '2025-10-06 14:41:03', 1, NULL),
(19, '1096063622', 'Marta García Milenas', 'herrerbrayandavid@gmail.com', 'Calle 14 No 10-13', '+573175527289', 'Marta', 'cliente', '2025-10-06 14:50:51', 1, NULL),
(21, '1074657888', 'Juan Manuel Gonzales Gomes', 'JuanManuel@gmail.com', 'Calle 14 No 14-25', '+573022762284', 'Juanm', 'empresa', '2025-10-21 01:00:53', 1, 'Emiraca-Express');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ventas`
--

CREATE TABLE `ventas` (
  `idVenta` int(11) NOT NULL,
  `idPedido` int(11) NOT NULL,
  `idUsuario` int(11) DEFAULT NULL,
  `monto_subtotal` decimal(10,2) NOT NULL COMMENT 'Monto antes de descuentos e impuestos',
  `descuentos` decimal(10,2) DEFAULT 0.00 COMMENT 'Monto total de descuentos',
  `impuestos` decimal(10,2) DEFAULT 0.00 COMMENT 'Monto total de impuestos',
  `monto_total` decimal(10,2) NOT NULL COMMENT 'Monto final de la venta',
  `fecha_venta` timestamp NULL DEFAULT current_timestamp(),
  `estado_venta` varchar(50) DEFAULT 'confirmada' COMMENT 'confirmada, anulada, pendiente',
  `costo_total` decimal(10,2) DEFAULT 0.00 COMMENT 'Suma de costos de los productos vendidos',
  `utilidad` decimal(10,2) DEFAULT 0.00 COMMENT 'Ganancia neta de la venta',
  `retencion_fuente` decimal(10,2) DEFAULT 0.00 COMMENT 'Retención en la fuente aplicada',
  `aplica_retefuente` tinyint(1) DEFAULT 0 COMMENT '1 = sí, el comprador aplicó retefuente'
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `ventas`
--

INSERT INTO `ventas` (`idVenta`, `idPedido`, `idUsuario`, `monto_subtotal`, `descuentos`, `impuestos`, `monto_total`, `fecha_venta`, `estado_venta`, `costo_total`, `utilidad`, `retencion_fuente`, `aplica_retefuente`) VALUES
(41, 71, 21, 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-10-21 01:24:29', 'confirmada', 2512000.00, 43888.00, 56550.00, 1),
(42, 72, 21, 5012000.00, 751800.00, 809438.00, 5084638.00, '2025-10-21 01:28:20', 'confirmada', 5012000.00, 72638.00, 112800.00, 1),
(43, 73, 19, 12000.00, 0.00, 2280.00, 29280.00, '2025-11-10 23:16:12', 'confirmada', 12000.00, 17280.00, 0.00, 0),
(45, 75, 19, 36000.00, 3600.00, 6156.00, 57156.00, '2025-11-11 01:05:53', 'confirmada', 36000.00, 21156.00, 0.00, 0),
(46, 76, 19, 5036000.00, 759000.00, 812732.60, 5108332.60, '2025-11-11 01:13:01', 'confirmada', 5036000.00, 72332.60, 0.00, 0),
(47, 77, 19, 5012000.00, 751800.00, 809438.00, 5084638.00, '2025-11-11 01:30:20', 'confirmada', 5012000.00, 72638.00, 0.00, 0),
(48, 78, 19, 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:32:13', 'confirmada', 2512000.00, 43888.00, 0.00, 0),
(49, 79, 19, 2524000.00, 378600.00, 407626.00, 2568026.00, '2025-11-11 01:35:09', 'confirmada', 2524000.00, 44026.00, 0.00, 0),
(50, 80, 19, 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:35:54', 'confirmada', 2512000.00, 43888.00, 0.00, 0),
(51, 81, 19, 2512000.00, 376800.00, 405688.00, 2555888.00, '2025-11-11 01:38:20', 'confirmada', 2512000.00, 43888.00, 0.00, 0);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `actividades`
--
ALTER TABLE `actividades`
  ADD PRIMARY KEY (`id_actividad`),
  ADD KEY `idx_actividad_tipo` (`tipo_actividad`),
  ADD KEY `idx_actividad_estado` (`estado`),
  ADD KEY `idx_actividad_usuario` (`id_usuario_asignado`),
  ADD KEY `idx_actividad_cliente` (`id_cliente`),
  ADD KEY `idx_actividad_usuario_estado` (`id_usuario_asignado`,`estado`);

--
-- Indices de la tabla `casos_soporte`
--
ALTER TABLE `casos_soporte`
  ADD PRIMARY KEY (`id_caso`),
  ADD KEY `idx_caso_cliente` (`id_cliente`),
  ADD KEY `idx_caso_prioridad` (`prioridad`),
  ADD KEY `idx_caso_estado` (`estado`),
  ADD KEY `idx_caso_cliente_estado` (`id_cliente`,`estado`);

--
-- Indices de la tabla `compra`
--
ALTER TABLE `compra`
  ADD PRIMARY KEY (`idCompra`),
  ADD KEY `idProveedor` (`idProveedor`);

--
-- Indices de la tabla `detallepedido`
--
ALTER TABLE `detallepedido`
  ADD PRIMARY KEY (`idDetallePedido`),
  ADD KEY `idPedido` (`idPedido`),
  ADD KEY `idProducto` (`idProducto`);

--
-- Indices de la tabla `detalle_compra`
--
ALTER TABLE `detalle_compra`
  ADD PRIMARY KEY (`idDetalleCompra`),
  ADD KEY `idCompra` (`idCompra`),
  ADD KEY `idProducto` (`idProducto`);

--
-- Indices de la tabla `formaspago`
--
ALTER TABLE `formaspago`
  ADD PRIMARY KEY (`idFormaPago`),
  ADD UNIQUE KEY `nombre` (`nombre`),
  ADD KEY `idx_formas_pago_activo` (`activo`);

--
-- Indices de la tabla `gastos`
--
ALTER TABLE `gastos`
  ADD PRIMARY KEY (`idGasto`),
  ADD KEY `idProducto` (`idProducto`);

--
-- Indices de la tabla `interacciones`
--
ALTER TABLE `interacciones`
  ADD PRIMARY KEY (`id_interaccion`),
  ADD KEY `idx_interaccion_cliente` (`id_cliente`),
  ADD KEY `idx_interaccion_tipo` (`tipo_interaccion`),
  ADD KEY `idx_interaccion_fecha` (`fecha_interaccion`),
  ADD KEY `fk_interaccion_usuario` (`id_usuario`);

--
-- Indices de la tabla `oportunidades`
--
ALTER TABLE `oportunidades`
  ADD PRIMARY KEY (`id_oportunidad`),
  ADD KEY `idx_oportunidad_cliente` (`id_cliente`),
  ADD KEY `idx_oportunidad_etapa` (`etapa`),
  ADD KEY `idx_oportunidad_cliente_etapa` (`id_cliente`,`etapa`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`idPago`),
  ADD KEY `idUsuario` (`idUsuario`),
  ADD KEY `idPedido` (`idPedido`),
  ADD KEY `idFormaPago` (`idFormaPago`),
  ADD KEY `idx_pagos_estado` (`estado_pago`),
  ADD KEY `idx_pagos_fecha` (`fecha_pago`),
  ADD KEY `idx_pagos_referencia` (`referencia_pago`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`idPedido`),
  ADD KEY `idUsuario` (`idUsuario`),
  ADD KEY `idx_pedidos_estado` (`estado`),
  ADD KEY `idx_pedidos_fecha` (`fecha_pedido`);

--
-- Indices de la tabla `producto`
--
ALTER TABLE `producto`
  ADD PRIMARY KEY (`idProducto`),
  ADD KEY `idx_producto_nombre` (`nombreProducto`),
  ADD KEY `idx_producto_activo` (`activo`),
  ADD KEY `fk_producto_proveedor` (`idProveedor`);

--
-- Indices de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  ADD PRIMARY KEY (`idProveedor`),
  ADD UNIQUE KEY `nit` (`nit`);

--
-- Indices de la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`idUsuario`),
  ADD UNIQUE KEY `cedula` (`cedula`),
  ADD KEY `idx_usuario_cedula` (`cedula`),
  ADD KEY `idx_usuario_rol` (`rol`);

--
-- Indices de la tabla `ventas`
--
ALTER TABLE `ventas`
  ADD PRIMARY KEY (`idVenta`),
  ADD KEY `idx_ventas_fecha` (`fecha_venta`),
  ADD KEY `idx_ventas_usuario` (`idUsuario`),
  ADD KEY `Ventas_ibfk_1` (`idPedido`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `actividades`
--
ALTER TABLE `actividades`
  MODIFY `id_actividad` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `casos_soporte`
--
ALTER TABLE `casos_soporte`
  MODIFY `id_caso` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT de la tabla `compra`
--
ALTER TABLE `compra`
  MODIFY `idCompra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

--
-- AUTO_INCREMENT de la tabla `detallepedido`
--
ALTER TABLE `detallepedido`
  MODIFY `idDetallePedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=117;

--
-- AUTO_INCREMENT de la tabla `detalle_compra`
--
ALTER TABLE `detalle_compra`
  MODIFY `idDetalleCompra` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT de la tabla `formaspago`
--
ALTER TABLE `formaspago`
  MODIFY `idFormaPago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `gastos`
--
ALTER TABLE `gastos`
  MODIFY `idGasto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT de la tabla `interacciones`
--
ALTER TABLE `interacciones`
  MODIFY `id_interaccion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=85;

--
-- AUTO_INCREMENT de la tabla `oportunidades`
--
ALTER TABLE `oportunidades`
  MODIFY `id_oportunidad` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `idPago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=81;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `idPedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=82;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `idProducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT de la tabla `proveedor`
--
ALTER TABLE `proveedor`
  MODIFY `idProveedor` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `idUsuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT de la tabla `ventas`
--
ALTER TABLE `ventas`
  MODIFY `idVenta` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=52;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `actividades`
--
ALTER TABLE `actividades`
  ADD CONSTRAINT `fk_actividad_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `usuario` (`idUsuario`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_actividad_usuario` FOREIGN KEY (`id_usuario_asignado`) REFERENCES `usuario` (`idUsuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `casos_soporte`
--
ALTER TABLE `casos_soporte`
  ADD CONSTRAINT `fk_caso_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `usuario` (`idUsuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `compra`
--
ALTER TABLE `compra`
  ADD CONSTRAINT `compra_ibfk_1` FOREIGN KEY (`idProveedor`) REFERENCES `proveedor` (`idProveedor`) ON DELETE CASCADE;

--
-- Filtros para la tabla `detallepedido`
--
ALTER TABLE `detallepedido`
  ADD CONSTRAINT `DetallePedido_ibfk_1` FOREIGN KEY (`idPedido`) REFERENCES `pedidos` (`idPedido`) ON DELETE CASCADE,
  ADD CONSTRAINT `DetallePedido_ibfk_2` FOREIGN KEY (`idProducto`) REFERENCES `producto` (`idProducto`);

--
-- Filtros para la tabla `detalle_compra`
--
ALTER TABLE `detalle_compra`
  ADD CONSTRAINT `detalle_compra_ibfk_1` FOREIGN KEY (`idCompra`) REFERENCES `compra` (`idCompra`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_compra_ibfk_2` FOREIGN KEY (`idProducto`) REFERENCES `producto` (`idProducto`) ON DELETE CASCADE;

--
-- Filtros para la tabla `gastos`
--
ALTER TABLE `gastos`
  ADD CONSTRAINT `gastos_ibfk_1` FOREIGN KEY (`idProducto`) REFERENCES `producto` (`idProducto`) ON DELETE CASCADE;

--
-- Filtros para la tabla `interacciones`
--
ALTER TABLE `interacciones`
  ADD CONSTRAINT `fk_interaccion_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `usuario` (`idUsuario`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_interaccion_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario` (`idUsuario`) ON DELETE SET NULL;

--
-- Filtros para la tabla `oportunidades`
--
ALTER TABLE `oportunidades`
  ADD CONSTRAINT `fk_oportunidad_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `usuario` (`idUsuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD CONSTRAINT `Pagos_ibfk_1` FOREIGN KEY (`idUsuario`) REFERENCES `usuario` (`idUsuario`) ON DELETE SET NULL,
  ADD CONSTRAINT `Pagos_ibfk_2` FOREIGN KEY (`idPedido`) REFERENCES `pedidos` (`idPedido`) ON DELETE CASCADE,
  ADD CONSTRAINT `Pagos_ibfk_3` FOREIGN KEY (`idFormaPago`) REFERENCES `formaspago` (`idFormaPago`);

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `Pedidos_ibfk_1` FOREIGN KEY (`idUsuario`) REFERENCES `usuario` (`idUsuario`) ON DELETE SET NULL;

--
-- Filtros para la tabla `producto`
--
ALTER TABLE `producto`
  ADD CONSTRAINT `fk_producto_proveedor` FOREIGN KEY (`idProveedor`) REFERENCES `proveedor` (`idProveedor`) ON DELETE SET NULL;

--
-- Filtros para la tabla `ventas`
--
ALTER TABLE `ventas`
  ADD CONSTRAINT `Ventas_ibfk_1` FOREIGN KEY (`idPedido`) REFERENCES `pedidos` (`idPedido`) ON DELETE CASCADE,
  ADD CONSTRAINT `Ventas_ibfk_2` FOREIGN KEY (`idUsuario`) REFERENCES `usuario` (`idUsuario`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
