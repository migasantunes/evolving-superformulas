import java.util.*; // Needed to sort arrays

// This class stores and manages a population of individuals (SuperFormulas).
class Population {
  
  SuperFormula[] individuals; // Array to store the individuals in the population
  int generations; // Integer to keep count of how many generations have been created
  
  Population() {
    individuals = new SuperFormula[population_size];
    initialize();
  }
  
  // Create the initial individuals
  void initialize() {
    // Fill population with random individuals
    for (int i = 0; i < individuals.length; i++) {
      individuals[i] = new SuperFormula();
    }
    
    // Reset generations counter
    generations = 0;
  }
  
  // Create the next generation
  void evolve() {
    // Create a new a array to store the individuals that will be in the next generation
    SuperFormula[] new_generation = new SuperFormula[individuals.length];
    
    // Sort individuals by fitness
    sortIndividualsByFitness();
    
    // Count number of individuals with fitness score
    int eliteSize = getEliteCount();
    
    // Copy the elite to the next generation
    for (int i = 0; i < eliteSize; i++) {
      new_generation[i] = individuals[i].getCopy();
    }
    
    // Create (breed) new individuals with crossover
    for (int i = eliteSize; i < population_size; i++) {
      SuperFormula newIndiv;
      if (random(1) < crossover_rate) {
        SuperFormula parent1 = rouletteSelection();
        SuperFormula parent2 = rouletteSelection();
        newIndiv = parent1.blxAlphaCrossover(parent2);
      } else {
        newIndiv = rouletteSelection().getCopy();
      }
      new_generation[i] = newIndiv;
    }
    
    // Mutate new individuals
    float sigma = sigma_max * pow(sigma_min / sigma_max, min(1, generations / (float) horizonG));
    for (int i = eliteSize; i < new_generation.length; i++) {
      new_generation[i].mutate(sigma);
    }
    
    // Replace the individuals in the population with the new generation individuals
    for (int i = 0; i < individuals.length; i++) {
      individuals[i] = new_generation[i];
    }
    
    // Reset the fitness of all individuals to 0
    for (int i = 0; i < individuals.length; i++) {
       individuals[i].setFitness(0);
    }
    
    // Increment the number of generations
    generations++;
  }

  SuperFormula rouletteSelection() {
    float totalFitness = 0;
    for (SuperFormula indiv : individuals){
      totalFitness = totalFitness + wheelWeight(indiv);
    }
    
    // Fallback if every rating is 0 and unrated_weight is 0: there is one individual chosen at random
    if (totalFitness == 0){
      return individuals[int(random(0, individuals.length))];
    }

    float hit = random(totalFitness);
    float addedFit = 0;

    for (SuperFormula indiv : individuals){
      addedFit = addedFit + wheelWeight(indiv);
      if (hit < addedFit){
        return indiv;
      }
    }

    return individuals[individuals.length - 1];
  }
  
  float wheelWeight(SuperFormula indiv) {
    float fit = indiv.getFitness();
    return (fit > 0) ? fit : unrated_weight;
  }

  int getEliteCount() {
    for (int i = 0; i < elite_max; i++){
      int fit = (int) individuals[i].getFitness();
      if (i == 0){
        if (fit == 0) {return 0;}
        if (fit != elite_fitness) {return elite_min;}
      }

      if (fit != elite_fitness) {return i;} 
    }
    
    return elite_max;
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
}
