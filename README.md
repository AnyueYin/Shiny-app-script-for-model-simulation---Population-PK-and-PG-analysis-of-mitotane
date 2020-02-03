## Shiny app script for model simulation - Population PK and PG analysis of mitotane 
Created by Anyue Yin from the Department of Clinical Pharmacy and Toxicology, Leiden University Medical Center, Leiden, the Netherlands.

**Related paper:** Anyue Yin, Madeleine H.T. Ettaieb, et al. Population pharmacokinetic and pharmacogenetic analysis of mitotane in patients with adrenocortical carcinoma: towards individualized dosing, 2020. *submitted*

**Software:** R statistics software (version 3.4.2; R Foundation for Statistical Computing, Vienna, Austria) 

**Main packages:**  shiny (version 1.4.0), RxODE (version 0.6-1) 

**Simulated regimen:**  Regimen where patient started with individualized dose which allowed the predicted mitotane concentration on day 98, which was simulated considering typical parameter values and covariate effects, reach the target. The blood samples were assumed to be collected once every 2 weeks after knowing the result of the last sample, and the concentration of mitotane was assumed to be known 7 days after blood collection. The dose amount was subsequently adjusted accordingly. If the monitored mitotane plasma concentration (C<sub>sim_real</sub>) < 14mg/L, the dosage increased by 0.5g till the target was reached or 126 days. Thereafter, the dosage increased by 1.5g if C<sub>sim_real</sub> < 14mg/L, remained unchanged if 14mg/L ≤ C<sub>sim_real</sub> < 18 mg/L, decreased by 1g if 18 mg/L ≤ C<sub>sim_real</sub> < 20 mg/L, and decreased by 4g if C<sub>sim_real</sub> ≥ 20 mg/L.
