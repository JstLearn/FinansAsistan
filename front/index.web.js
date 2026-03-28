// Suppress React Native Web touch history warnings BEFORE imports
const _originalWarn = console.warn.bind(console);
console.warn = function(...args) {
  const msg = args[0];
  if (typeof msg === 'string' && (
    msg.includes('Cannot record touch end without a touch start') ||
    msg.includes('Cannot record touch move without a touch start')
  )) {
    return;
  }
  _originalWarn(...args);
};

import { AppRegistry } from 'react-native';
import App from './front';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);

AppRegistry.runApplication(appName, {
  initialProps: {},
  rootTag: document.getElementById('root'),
});
