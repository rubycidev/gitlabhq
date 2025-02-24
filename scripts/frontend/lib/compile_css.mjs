import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { env } from 'node:process';
import { compile, Logger } from 'sass';
import glob from 'glob';
/* eslint-disable import/extensions */
import IS_EE from '../../../config/helpers/is_ee_env.js';
import IS_JH from '../../../config/helpers/is_jh_env.js';
/* eslint-enable import/extensions */

// Note, in node > 21.2 we could replace the below with import.meta.dirname
const ROOT_PATH = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../');
const OUTPUT_PATH = path.join(ROOT_PATH, 'app/assets/builds/');

const BASE_PATH = 'app/assets/stylesheets';
const EE_BASE_PATH = 'ee/app/assets/stylesheets';
const JH_BASE_PATH = 'jh/app/assets/stylesheets';

// SCSS files starting with an underscore are partials
// and not meant to be compiled, usually
const SCSS_PARTIAL_GLOB = '**/_*.scss';

/**
 * This function returns an array of paths where `sass` will look for includes
 * It ensures that the `ee/` and `jh/` directories take precedence, so that the
 * correct file is loaded.
 */
function resolveLoadPaths() {
  const loadPaths = {
    base: [BASE_PATH],
    vendor: [
      // no-op files
      'app/assets/stylesheets/_ee',
      'app/assets/stylesheets/_jh',
      // loaded last
      'vendor/assets/stylesheets', // empty
      'node_modules',
    ],
  };

  if (IS_EE) {
    loadPaths.base.unshift(EE_BASE_PATH);
    loadPaths.vendor.unshift('ee/app/assets/stylesheets/_ee');
  }
  if (IS_JH) {
    loadPaths.base.unshift(JH_BASE_PATH);
    loadPaths.vendor.unshift('jh/app/assets/stylesheets/_jh');
  }
  return Object.values(loadPaths)
    .flat()
    .map((p) => path.resolve(ROOT_PATH, p));
}

/**
 *
 * @param {string} globPath glob to be used for finding source files
 * @param {Object} [options]
 * @param {string[]} [options.ignore=['**\/_*.scss']] File names to be ignored (glob).
 *   Per default ignores SCSS partial files
 * @param {string} [options.basePath='app/assets/javascripts'] Base path of the globPath.
 *   Will be used for the target to put the resulting files in the correct folder structure.
 * @example
 * // Assuming the folder contains bar.scss and the partial _baz.scss, this would return
 * // [{
 * //   source: 'app/assets/stylesheets/foo/bar.scss',
 * //   dest: 'app/assets/builds/foo/bar.css'
 * // }]
 * findSourceFiles('app/assets/stylesheets/foo/*.scss')
 * @returns {{source: string, dest: string }[]}
 */
function findSourceFiles(globPath, options = {}) {
  const { ignore = [SCSS_PARTIAL_GLOB], basePath = BASE_PATH } = options;
  console.log('Resolving source', globPath);

  const scssPaths = path.join(ROOT_PATH, globPath);

  return glob.sync(scssPaths, { ignore }).map((sourceFile) => {
    const relSourcePath = path.relative(path.join(ROOT_PATH, basePath), sourceFile);
    const destFile = path.join(OUTPUT_PATH, relSourcePath).replace(/\.scss$/, '.css');

    return { source: sourceFile, dest: destFile };
  });
}

/**
 * This function returns a Map<inputPath, outputPath> of absolute paths
 * which map from a SCSS source file to a CSS output file.
 *
 * The reason why it's a Map, rather than an array, if for example both
 * - app/assets/stylesheets/page_bundles/milestone.scss
 * - ee/app/assets/stylesheets/page_bundles/milestone.scss
 * exist. Then only the latter needs to be compiled and the former ignored.
 * In practise, the EE version often imports the CE version and extends it,
 * but theoretically they could be completely separate files.
 *
 */
function resolveCompilationTargets() {
  const inputGlobs = [
    [
      'app/assets/stylesheets/*.scss',
      {
        ignore: [
          SCSS_PARTIAL_GLOB,
          '**/bootstrap_migration*', // TODO: Prefix file name with _ (and/or move to framework)
          '**/utilities.scss', // TODO: Prefix file name with _
        ],
      },
    ],
    [
      'app/assets/stylesheets/{highlight/themes,lazy_bundles,mailers,page_bundles,themes}/**/*.scss',
    ],
    // This is explicitly compiled to ensure that we do not end up with actual class definitions in this file
    // See scripts/frontend/check_page_bundle_mixins_css_for_sideeffects.js
    [
      'app/assets/stylesheets/page_bundles/_mixins_and_variables_and_functions.scss',
      { ignore: [] },
    ],
    // TODO: Figure out why _these_ are compiled from within the highlight folder.
    [
      'app/assets/stylesheets/highlight/{diff_custom_colors_addition.scss,diff_custom_colors_deletion.scss}',
    ],
    // TODO: find out why this is explicitly compiled
    ['app/assets/stylesheets/themes/_dark.scss', { ignore: [] }],
  ];

  if (IS_EE) {
    inputGlobs.push([
      'ee/app/assets/stylesheets/page_bundles/**/*.scss',
      {
        basePath: EE_BASE_PATH,
      },
    ]);
  }

  if (IS_JH) {
    inputGlobs.push([
      'jh/app/assets/stylesheets/page_bundles/**/*.scss',
      {
        basePath: JH_BASE_PATH,
      },
    ]);
  }

  /**
   * This is map mapping from outputPath => inputPath, to ensure that
   * every outputPath just has a single source path.
   * @type {Map<string, string>}
   */
  const result = new Map();

  for (const [sourcePath, options] of inputGlobs) {
    const sources = findSourceFiles(sourcePath, options);
    console.log(`${sourcePath} resolved to:`, sources);
    for (const { source, dest } of sources) {
      result.set(dest, source);
    }
  }

  /*
   * Here we reverse the result map to be inputPath => outputPath,
   * because for our further use cases we need the mapping this way.
   */
  return Object.fromEntries([...result.entries()].map((entry) => entry.reverse()));
}

export async function compileAllStyles({ shouldWatch = false }) {
  const reverseDependencies = {};

  const compilationTargets = resolveCompilationTargets();

  const sassCompilerOptions = {
    loadPaths: resolveLoadPaths(),
    logger: Logger.silent,
  };

  let fileWatcher = null;
  if (shouldWatch) {
    const { watch } = await import('chokidar');
    fileWatcher = watch([]);
  }

  async function compileSCSSFile(source, dest) {
    console.log(`\tcompiling source ${source} to ${dest}`);
    const content = compile(source, sassCompilerOptions);
    if (fileWatcher) {
      for (const dependency of content.loadedUrls) {
        if (dependency.protocol === 'file:') {
          const dependencyPath = fileURLToPath(dependency);
          reverseDependencies[dependencyPath] ||= new Set();
          reverseDependencies[dependencyPath].add(source);
          fileWatcher.add(dependencyPath);
        }
      }
    }
    // Create target folder if it doesn't exist
    await mkdir(path.dirname(dest), { recursive: true });
    return writeFile(dest, content.css, 'utf-8');
  }

  if (fileWatcher) {
    fileWatcher.on('change', async (changedFile) => {
      console.warn(`${changedFile} changed, recompiling`);
      const recompile = [];
      for (const source of reverseDependencies[changedFile]) {
        recompile.push(compileSCSSFile(source, compilationTargets[source]));
      }
      await Promise.all(recompile);
    });
  }

  const initialCompile = Object.entries(compilationTargets).map(([source, dest]) =>
    compileSCSSFile(source, dest),
  );

  await Promise.all(initialCompile);

  return fileWatcher;
}

function shouldUseNewPipeline() {
  return /^(true|t|yes|y|1|on)$/i.test(`${env.USE_NEW_CSS_PIPELINE}`);
}

export function viteCSSCompilerPlugin({ shouldWatch = true }) {
  if (!shouldUseNewPipeline()) {
    return null;
  }
  let fileWatcher = null;
  return {
    name: 'gitlab-css-compiler',
    async configureServer() {
      fileWatcher = await compileAllStyles({ shouldWatch });
    },
    buildEnd() {
      return fileWatcher?.close();
    },
  };
}

export function simplePluginForNodemon({ shouldWatch = true }) {
  if (!shouldUseNewPipeline()) {
    return null;
  }
  let fileWatcher = null;
  return {
    async start() {
      await fileWatcher?.close();
      fileWatcher = await compileAllStyles({ shouldWatch });
    },
    stop() {
      return fileWatcher?.close();
    },
  };
}
