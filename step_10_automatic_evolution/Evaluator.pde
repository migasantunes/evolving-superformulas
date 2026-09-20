// This class enables the evaluation of individuals (SuperFormulas).
//
// Fitness is a multi-scale Dice coefficient over binarised ink maps, not a raw-brightness RMSE.
// RMSE was replaced because it made a blank canvas the best possible answer for line-art targets:
//   - the targets are 2000px exports downsampled to the evaluation size, so their strokes come out
//     faint grey, while the phenotype draws solid black; every correct pixel was still penalised
//   - RMSE also scales with how much ink the target has, so for a thin target "draw nothing" beat
//     every imperfect attempt
// Dice compares which pixels are inked rather than how dark they are, so it is immune to both:
// it is 0 for a blank canvas and 1 for an exact match, whatever fraction of the canvas is inked.
class Evaluator {

  int res; // Resolution at which individuals are evaluated
  int[] levels = {1, 2, 4, 8}; // Block sizes of the pyramid; 1 is full resolution
  float ink_threshold = 0.02; // How dark a pixel must be to count as ink
  float[][] target_pyramid; // Pooled ink maps of the target, one per level

  Evaluator(PImage image, int resolution) {
    res = resolution;
    PImage target_image = image.copy(); // Get a clean copy of the target image
    target_image.resize(res, res); // Resize the target image to the preset resolution
    target_pyramid = buildPyramid(getInk(target_image));
  }

  // Calculate the fitness of a given individual (this is the fitness function)
  float calculateFitness(SuperFormula indiv) {
    float[][] phenotype_pyramid = buildPyramid(getInk(indiv.getPhenotype(res)));
    float similarity = 0;
    for (int l = 0; l < levels.length; l++) {
      similarity += dice(target_pyramid[l], phenotype_pyramid[l]);
    }
    return similarity / levels.length; // Average the levels so the result stays in [0, 1]
  }

  // Turn an image into a binary ink map: 1 where the image has a mark, 0 where it is blank.
  // Binarising here is what removes the faint-target/solid-phenotype mismatch.
  float[] getInk(PImage image) {
    image.loadPixels();
    float[] ink = new float[image.pixels.length];
    for (int i = 0; i < image.pixels.length; i++) {
      float darkness = (255 - (image.pixels[i] & 0xFF)) / 255.0; // Blue channel, as before
      ink[i] = (darkness > ink_threshold) ? 1 : 0;
    }
    return ink;
  }

  // Build the pooled copies of an ink map, one per level
  float[][] buildPyramid(float[] ink) {
    float[][] pyramid = new float[levels.length][];
    for (int l = 0; l < levels.length; l++) {
      pyramid[l] = pool(ink, levels[l]);
    }
    return pyramid;
  }

  // Average k x k blocks of an ink map. This is a blur and a downsample in one, and it is what
  // gives a near miss a gradient to climb: two shapes that never overlap pixel for pixel still
  // overlap once the map is coarse enough.
  float[] pool(float[] ink, int k) {
    if (k == 1) {
      return ink;
    }
    int n = ceil(res / (float) k);
    float[] sum = new float[n * n];
    float[] count = new float[n * n];
    for (int y = 0; y < res; y++) {
      for (int x = 0; x < res; x++) {
        int index = (y / k) * n + (x / k);
        sum[index] += ink[y * res + x];
        count[index] += 1;
      }
    }
    for (int i = 0; i < sum.length; i++) {
      if (count[i] > 0) {
        sum[i] /= count[i];
      }
    }
    return sum;
  }

  // Dice coefficient between two ink maps.
  // The aa + bb denominator (rather than sum(a) + sum(b)) makes it exactly 1 when the two maps are
  // equal, which the plain form does not do once the maps hold pooled, non-binary values.
  float dice(float[] a, float[] b) {
    float ab = 0, aa = 0, bb = 0;
    for (int i = 0; i < a.length; i++) {
      ab += a[i] * b[i];
      aa += a[i] * a[i];
      bb += b[i] * b[i];
    }
    float denominator = aa + bb;
    return (denominator > 1e-9) ? 2 * ab / denominator : 0; // Both blank counts as no similarity
  }
}
