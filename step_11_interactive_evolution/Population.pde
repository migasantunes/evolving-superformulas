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
    int eliteSizeAdjusted = min(elite_size, getPreferredIndivsShuffled().size());
    
    // Copy the elite to the next generation
    for (int i = 0; i < eliteSizeAdjusted; i++) {
      new_generation[i] = individuals[i].getCopy();
    }
    
    // Create (breed) new individuals with crossover
    for (int i = eliteSizeAdjusted; i < population_size; i++) {
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
    System.out.println("sigma: " + sigma);
    for (int i = eliteSizeAdjusted; i < new_generation.length; i++) {
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
  
  /**
   * Return one individual selected using tournament.
   */
  SuperFormula tournamentSelectionV2() {
    // Define pool of individuals from which one will be selected by tournament
    SuperFormula[] selectionPool;
    ArrayList<SuperFormula> prefferedIndividuals = getPreferredIndivsShuffled();
    if (prefferedIndividuals.size() > 1) {
      Collections.shuffle(prefferedIndividuals);
      selectionPool = prefferedIndividuals.toArray(new SuperFormula[0]);
    } else if (prefferedIndividuals.size() == 1) {
      return prefferedIndividuals.get(0);
    } else {
      selectionPool = individuals;
    }
    
    // Select a set of individuals at random
    SuperFormula[] tournament = new SuperFormula[tournament_size];
    for (int i = 0; i < tournament.length; i++) {
      int randomIndex = int(random(0, selectionPool.length));
      tournament[i] = selectionPool[randomIndex];
    }

    // Return the fittest individual from the selected ones
    SuperFormula fittest = tournament[0];
    for (int i = 1; i < tournament.length; i++) {
      if (tournament[i].getFitness() > fittest.getFitness()) {
        fittest = tournament[i];
      }
    }
    return fittest;
  }
  
  // Select one individual using a tournament selection 
  SuperFormula tournamentSelection() {
    // Select a random set of individuals from the population
    SuperFormula[] tournament = new SuperFormula[tournament_size];
    for (int i = 0; i < tournament.length; i++) {
      int random_index = int(random(0, individuals.length));
      tournament[i] = individuals[random_index];
    }
    // Get the fittest individual from the selected individuals
    SuperFormula fittest = tournament[0];
    for (int i = 1; i < tournament.length; i++) {
      if (tournament[i].getFitness() > fittest.getFitness()) {
        fittest = tournament[i];
      }
    }
    return fittest;
  }

  SuperFormula rouletteSelection() {
    float totalFitness = 0;
    for (SuperFormula indiv : individuals){
      totalFitness = totalFitness + indiv.getFitness();
    }
    
    // If every fitness is 0 there is one individual chosen at random
    if (totalFitness == 0){
      int random_index = int(random(0, individuals.length));
      return individuals[random_index];
    }

    float hit = random(totalFitness);
    float addedFit = 0;

    for (SuperFormula indiv : individuals){
      addedFit = addedFit + indiv.getFitness();
      if (hit < addedFit){
        return indiv;
      }
    }

    return individuals[individuals.length - 1];
  }
  
  /**
   * Returns list with individuals with fitness greater than zero.
   */
  ArrayList<SuperFormula> getPreferredIndivsShuffled() {
    ArrayList<SuperFormula> output = new ArrayList<SuperFormula>();
    for (SuperFormula indiv : individuals) {
      if (indiv.getFitness() > 0) {
        output.add(indiv);
      }
    }
    return output;
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
