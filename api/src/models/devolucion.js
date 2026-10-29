const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Prestamo = require('./prestamo');

const Devolucion = sequelize.define('devoluciones', {
  id_devolucion: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  id_prestamo: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Prestamo,
      key: 'id_prestamo'
    }
  },
  fecha_devolucion: {
    type: DataTypes.DATEONLY,
    allowNull: false,
    defaultValue: DataTypes.NOW
  },
  observaciones: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  timestamps: false,
  freezeTableName: true
});

Prestamo.hasOne(Devolucion, { foreignKey: 'id_prestamo', as: 'devolucion', onDelete: 'CASCADE' });
Devolucion.belongsTo(Prestamo, { foreignKey: 'id_prestamo', as: 'prestamo' });

module.exports = Devolucion;
