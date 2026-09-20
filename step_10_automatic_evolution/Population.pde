import java.util.*; // Needed to sort arrays

// This class stores and manages a population of individuals (SuperFormulas).
class Population {
  
  SuperFormula[] individuals; // Array to store the individuals in the population
  Evaluator evaluator; // Object to calculate fitness of individuals
  int generations; // Integer to keep count of how many generations have been created
  
  Population() {
    individuals = new SuperFormula[population_size];
    evaluator = new Evaluator(loadImage(path_target_image), resolution);
    initialize();
  }
  
  // Create the initial individuals
  void initialize() {
    // Fill population with random individuals
    for (int i = 0; i < individuals.length; i++) {
      individuals[i] = new SuperFormula();
    }
    
    // Evaluate individuals
    for (int i = 0; i < individuals.length; i++) {
      float fitness = evaluator.calculateFitness(individuals[i]);
      individuals[i].setFitness(fitness);
    }
    
    // Sort individuals in the population by fitness (fittest first)
    sortIndividualsByFitness();
    
    // Reset generations counter
    generations = 0;
  }
  
  // Create the next generation
  void evolve() {
    // Create a new array to store the individuals that will be in the next generation
    SuperFormula[] new_generation = new SuperFormula[individuals.length];
    
    // Copy the elite to the next generation (we assume that the individuals are already sorted by fitness)
    for (int i = 0; i < elite_size; i++) {
      new_generation[i] = individuals[i].getCopy();
    }
    
    // Create (breed) new individuals with crossover
    for (int i = elite_size; i < new_generation.length; i++) {
      if (random(1) <= crossover_rate) {
        SuperFormula parent1 = rouletteSelectionLinearRanking();
        SuperFormula parent2 = rouletteSelectionLinearRanking();
        SuperFormula child = parent1.blxAlphaCrossover(parent2);
        new_generation[i] = child;
      } else {
        new_generation[i] = rouletteSelectionLinearRanking().getCopy();
      }
    }
    
    // Mutate new individuals
    
    for (int i = elite_size; i < new_generation.length; i++) {
      new_generation[i].mutate();
    }
    
    // Evaluate new individuals
    for (int i = elite_size; i < individuals.length; i++) {
      float fitness = evaluator.calculateFitness(new_generation[i]);
      new_generation[i].setFitness(fitness);
    }
    
    // Replace the individuals in the population with the new generation individuals
    for (int i = 0; i < individuals.length; i++) {
      individuals[i] = new_generation[i];
    }
    
    // Sort individuals in the population by fitness
    sortIndividualsByFitness();
    
    // Increment the number of generations
    generations++;
  }
  
  SuperFormula rouletteSelectionLinearRanking() {
    int n = individuals.length;
    float hit = random(n); // the linear-rank weights always add up to the population size
    float addedFit = 0;
    for (int i = 0; i < n; i++) {
      addedFit = addedFit + rankWeight(i, n);
      if (hit < addedFit) {
        return individuals[i];
      }
    }
    return individuals[n - 1];
  }

  // Linear ranking formula
  float rankWeight(int rank, int n) {
    return 2 - selection_pressure + 2 * (selection_pressure - 1) * (n - 1 - rank) / (float) (n - 1);
  }

  // Sort individuals in the population by fitness in descending order (fittest first)
  void sortIndividualsByFitness() {
    Arrays.sort(individuals, new Comparator<SuperFormula>() {
      public int compare(SuperFormula indiv1, SuperFormula indiv2) {
        return Float.compare(indiv2.getFitness(), indiv1.getFitness());
      }
    });
  }
  
  // Get an individual from the popultioon located at the given index
  SuperFormula getIndiv(int index) {
    return individuals[index];
  }
  
  // Get the number of individuals in the population
  int getSize() {
    return individuals.length;
  }
  
  // Get the number of generations that have been created so far
  int getGenerations() {
    return generations;
  }

  // Get the fitness of the best individual (the population is kept sorted, so it is the first one)
  float getBestFitness() {
    return individuals[0].getFitness();
  }

  // Get the average fitness of the population; next to the best it shows how much spread is left
  // for selection to act on, which is what fitness-proportional selection depends on
  float getMeanFitness() {
    float total = 0;
    for (SuperFormula indiv : individuals) {
      total = total + indiv.getFitness();
    }
    return total / individuals.length;
  }
}
