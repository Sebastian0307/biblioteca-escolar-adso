const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Usuario = require('./usuario');
const Ejemplar = require('./ejemplar');

const Solicitud = sequelize.define('solicitudes_prestamo', {
  id_solicitud: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  id_usuario: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Usuario,
      key: 'id_usuario'
    }
  },
  id_ejemplar: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Ejemplar,
      key: 'id_ejemplar'
    }
  },
  estado: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'pendiente',
    validate: {
      isIn: [['pendiente', 'aprobada', 'rechazada']]
    }
  }
}, {
  timestamps: false,
  freezeTableName: true
});

Usuario.hasMany(Solicitud, { foreignKey: 'id_usuario', as: 'solicitudes', onDelete: 'CASCADE' });
Solicitud.belongsTo(Usuario, { foreignKey: 'id_usuario', as: 'usuario' });

Ejemplar.hasMany(Solicitud, { foreignKey: 'id_ejemplar', as: 'solicitudes', onDelete: 'CASCADE' });
Solicitud.belongsTo(Ejemplar, { foreignKey: 'id_ejemplar', as: 'ejemplar' });

module.exports = Solicitud;
