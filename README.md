## **DL4H598 Final Project** (Repo is WIP - Work in Progress)
### Project Team #44 - Miles Kopcke and Sergio Rio
### {mkopcke2, sav7}@illinois.edu
### Paper ID #12 - ["Using recurrent neural network models for early detection of heart failure onset"](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5391725/)
### Edward Choi, Andy Schuetz, Walter F Stewart, and Jimeng Sun

### Overview
### The scope of this project is to reproduce the main  results claimed by the authors to be “state-of-the-art prediction performance,” outperforming traditional machine learning models. We will run experiments with the two GRU models (with and without time duration information) and the MLP model described in the research paper for all three types of inputs (one-hot encoding, grouped codes, and medical concept vectors based on Skip-gram). 
### The original study used data from Sutter Palo Alto Medical Foundation (Sutter-PAMF) primary care patients from May 16, 2000, to May 23, 2023. This data was used to construct 3,884 Heart Failure cases and 28,903 controls. Currently, we’re pursuing the use of the IBM MarketScan Research Database (Merative n.d.) as one of our team members works for IBM Watson Health (now called Merative). This would allow us to have a very similar patient population to the original study.

### In this project we tested the following claims:
### 1.The GRU models overperform t\e MLP model in AUC scores (see table 1 for detailed scores comparison) for all three types of inputs.
### 2.The GRU model with duration information presents a better AUC score than GRU without duration information (see table 1 for detailed scores comparison).
### 3.Confirm prediction times of GRU and MLP models for a single patient are similar to or lower than those reported in the paper (table 2), considering the evolution of CPU processing power since the paper was written.

### As of 4/16/2023 this is project is im "draft phase" with premilinary results confirming successful MarketScan data extraction, preparation, loading and first interation of baseline models (MLP and GRU with multi-hot vector encoding of EHR).

####  *Choi, Edward, Andy Schuetz, Walter F Stuart, and Jimeng Sun. 2016. "Using recurrent neural network models for early detection of heart failure onset." Journal of the American Medical Informatics Association 24 (2): 361-369. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5391725/.
