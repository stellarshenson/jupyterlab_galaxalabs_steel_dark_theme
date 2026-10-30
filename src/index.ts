import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

import { IThemeManager } from '@jupyterlab/apputils';

/**
 * Initialization data for the @stellarshenson/galaxalabs-jupyterlab-steel-dark-theme extension.
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: '@stellarshenson/galaxalabs-jupyterlab-steel-dark-theme:plugin',
  description:
    'Dark theme based on Sublime text editor default dark theme, tweaked by Stellars',
  autoStart: true,
  requires: [IThemeManager],
  activate: (app: JupyterFrontEnd, manager: IThemeManager) => {
    console.log(
      'JupyterLab extension @stellarshenson/galaxalabs-jupyterlab-steel-dark-theme is activated!'
    );
    const style =
      '@stellarshenson/galaxalabs-jupyterlab-steel-dark-theme/index.css';

    manager.register({
      name: 'Galaxa Dark Theme - Steel',
      themeScrollbars: true,
      isLight: false,
      load: () => manager.loadCSS(style),
      unload: () => Promise.resolve(undefined)
    });
  }
};

export default plugin;
