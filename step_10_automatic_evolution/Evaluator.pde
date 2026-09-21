// This class enables the evaluation of individuals (SuperFormulas).
// Dice compares which pixels are inked rather than how dark they are, so it is immune to both:
// it is 0 for a blank canvas and 1 for an exact match, whatever fraction of the canvas is inked.
class Evaluator {

  int res;
  int[] levels = {1, 2, 4, 8}; // Block sizes of the pyramid;
  float[] level_weights = {1, 0.5, 0.25, 0.125};
  float ink_threshold = 0.02; // How dark a pixel must be to count as ink
  float[][] target_pyramid; // Pooled ink maps of the target, one per level

  Evaluator(PImage image, int resolution) {
    res = resolution;
    PImage target_image = image.copy();
    target_image.resize(res, res);
    target_pyramid = buildPyramid(getInk(target_image));
  }

  // Calculate the fitness of a given individual (this is the fitness function)
  float calculateFitness(SuperFormula indiv) {
    float[][] phenotype_pyramid = buildPyramid(getInk(indiv.getPhenotype(res)));
    float similarity = 0;
    float total_weight = 0;
    for (int l = 0; l < levels.length; l++) {
      similarity += level_weights[l] * dice(target_pyramid[l], phenotype_pyramid[l]);
      total_weight += level_weights[l];
    }
    return similarity / total_weight; // Weighted average, so the result still stays in [0, 1]
  }

  // Turn an image into a binary ink map: 1 where the image has a mark, 0 where it is blank.
  float[] getInk(PImage image) {
    image.loadPixels();
    float[] ink = new float[image.pixels.length];
    for (int i = 0; i < image.pixels.length; i++) {
      float darkness = (255 - (image.pixels[i] & 0xFF)) / 255.0;
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

  // Average k x k blocks of an ink map. This is a blur and a downsample in one
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
