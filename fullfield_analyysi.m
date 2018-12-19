function [trials] = fullfield_analyysi()

    load bg_LED_calib_06092018.mat %#ok
    addpath('/Users/samutienhaara/Desktop/data_analyysi/Palamedes')
    addpath('/Users/samutienhaara/Desktop/data_analyysi')
    %Kutsutaan konkatenaatiokoodi, jolla voidaan per‰kk‰inasetella kaikki
    %sessioon kuuluvat sarjat
    totalstruct = universal_folder_struct_concatenator();
    %Luodaan tyhj‰ matriisi, jotta se voidaan t‰ytt‰‰ myˆhemmin
    totalmatrix = [];
    %Luodaan for-loop, joka k‰y l‰pi koko structin
    for s = 1:length(totalstruct) 
        %Nimet‰‰n totalstructista lˆytyv‰ kentt‰, joka sis‰lt‰‰ yhden
        %sarjan kaikki tiedot, e.g. eksentrisyys, filtterit, data, jne.
        temp_struct = totalstruct(s).session_struct;
        %Nimet‰‰n temp_structista lˆytyv‰ kentt‰, joka sis‰lt‰‰ yhden
        %sarjan datan
        session_matrix = temp_struct.session_matrix;
        %T‰ytet‰‰n aiemmin luotu totalmatrix kaikista session_matrixeista
        %konkatenoidulla matrixilla koko session datasta
        totalmatrix = [totalmatrix; session_matrix]; %#ok
        %oletetaan, ett‰ filtterikombo s‰ilyy samana l‰pi sarjojen
        if s == 1 
            stim_dur = temp_struct.stim_duration;
            filters = temp_struct.filters;
            filter_sum = 0;
            for f = 1:length(filters)
                if abs (filters(f) + 1.75) > 0.15 %tarkistetaan onko filtteri interferenssi vai ND, 1.75 = interferenssiattenuaatio
                    filter_sum = filter_sum + filters(f); %ND-filterit sama sek‰ radio- ett‰ fotometrin kannalta
                else
                    filter_sum = filter_sum - 1.047; %fotometrinen attenuaatiolukema (radiometriset lukemat ei kelpaa)
                end
                
            end
            
            baseline_voltage = temp_struct.bg_baseline_volt;
            
            filter_attenuation = 10^(filter_sum);
        end
        
    end

    %Haetaan totalmatrixin toisesta kolumnista lˆytyv‰t uniikit
    %intensiteetit, ja tallennetaan ne muuttujaksi 'ints_voltage'
    ints_voltage = unique(totalmatrix(:,2));
    max_rstar_per_rod = 721;
    max_intensity_watts = bg_LED_calib_06092018(9.506);
    rstar_per_rod_per_nanowatt = filter_attenuation ...
        * (max_rstar_per_rod / max_intensity_watts);
    
    baseline_intensity = bg_LED_calib_06092018(baseline_voltage) ...
        * rstar_per_rod_per_nanowatt
    log_baseline_intensity = log10(baseline_intensity)

    
    
    
    %Luodaan tyhj‰ cell array, joka voidaan myˆhemmin t‰ydent‰‰
    %erityyppisell‰ datalla. Cell arrayn jokaiseen soluun luodaan jokaista
    %intensiteettiluokkaa vastaava tyhj‰ vektori
    trials = {};
    for i = 1:length(ints_voltage)
       trials{i} = []; %#ok
    end
    
    %Luodaan totalmatrixin kolumneja 2, 3 ja 4 vastaavat muuttujat
    %intensiteetti, interval(inkrementti v‰l‰hdyksell‰ 3 vai 4) ja vastaus
    for t = 1:length(totalmatrix(:,1))
        intensity = totalmatrix(t,2);
        interval = totalmatrix(t,3);
        answer = totalmatrix(t,4);
        %Tai -logiikkaoperaattorilla yhdistetty kaksi
        %-logiikkaoperaattorilla yhdistetty‰ tarkastusta. Correct on
        %boolean, joka kertoo oliko vastaus oikein (painettu 1 ja v‰l‰hdys
        %3:nnella tai painettu 2 ja v‰l‰hdys 4:nnell‰ --> 1) vai v‰‰rin (0)
        correct = (interval == 1 && answer == 49) || ...
                  (interval == 2 && answer == 50);
        %Int_vector_length laskee kuinka moneen soluun on jo tallennettu
        %correctin arvo, k‰ytt‰en funktiota intensity_index.
        int_vector_length = length(trials{retrieve_intensity_index(intensity, ints_voltage)});
        
        %Tallennetaan uusi correct-arvo uuteen soluun trialsissa,
        %int_vector_length(cell_arrrayn pituus) +1.
        trials{retrieve_intensity_index(intensity, ints_voltage)}(int_vector_length +1) ...
            = correct; %#ok
    end
    
    %Luodaan vektori pcorr, joka on kunkin intensiteettiluokan
    %oikeiden vastausten arvioitu todenn‰kˆisyys. Pcorr saadaan ottamalla
    %oikeiden ja v‰‰rien vastausten keskiarvo
    pcorr = [];
    reps_vector = [];
    error_bars = [];
    for i = 1:length(ints_voltage)
        pcorr(i) = mean(trials{i}); %#ok
        reps_vector(i) = length(trials{i}); %toistojen m‰‰r‰ intensiteettiluokassa
        error_bars(i) = ((std(trials{i})) / (sqrt(reps_vector(i)))); %* 1.96
    end
    
    stim_type = 'increment';
    fill_color = 'c';
    line_color = 'b';
    if min(ints_voltage) < baseline_voltage
       stim_type = 'decrement'; 
       fill_color = 'm';
       line_color = 'r';
    end
   
    ints_rstar_per_rod = [];
    for i = 1:length(ints_voltage)
        if ints_voltage(i) ~= -0.05
            temp_nanowatts = bg_LED_calib_06092018(ints_voltage(i)); %antaa tuloksen nanowatteina
            ints_rstar_per_rod(i) = rstar_per_rod_per_nanowatt * temp_nanowatts;
            ints_rstar_per_rod(i) = abs (ints_rstar_per_rod(i) - baseline_intensity); %#ok
            ints_rstar_per_rod(i) = ints_rstar_per_rod(i) * stim_dur; %skaalataan ‰rsykkeen pituuden mukaan
            ints_rstar_per_rod(i) = log10(ints_rstar_per_rod(i)); %muutetaan intensiteetti logaritmimuotoon, jotta palamedes voi sovittaa k‰yr‰n
        end
        
    end
    
    if strcmp (stim_type, 'decrement')
        ints_rstar_per_rod = fliplr(ints_rstar_per_rod);
        pcorr = fliplr(pcorr);
        error_bars = fliplr(error_bars);
    end
    
    ints_rstar_per_rod(1) = ints_rstar_per_rod(2) - 4;
    
    %[kumulatiivisen normaalijakauman parametrit, parametrien
    %luottamusv‰lit
    %[incr_fitparams, incr_SD, incr_paramsSim, incr_90_thr, incr_90_thr_sd , ~] = ...    
    %         Palamedes_Basics_universal(ints_rstar_per_rod', ...
    %                                         pcorr', ...
    %                                         reps_vector', 0 );

    x_axis = linspace(ints_rstar_per_rod(1) - 0.5, ints_rstar_per_rod(end) + 0.5, 400);
    
    log_baseline_intensity = log10(baseline_intensity);
    
    ints_rstar_per_rod;
    pcorr;
    
    
    
    psychometric_fit_and_plot(ints_rstar_per_rod', pcorr', error_bars, ...
        reps_vector', x_axis, 1, 1, 0, fill_color, line_color);
    
%     plot(ints_voltage, pcorr);
 
    
end

%Luodaan funktio retrieve_intensity_index, jossa parametrein‰ intensity ja
%intensity_classes (haetaan koodissa muuttujista intenisty ja ints_voltage)
function [intensity_index] = retrieve_intensity_index(intensity, intensity_classes)
    %T‰t‰ kohtaa koodista en ymm‰rr‰, mutta se n‰ytt‰‰ hakevan
    %indeksoivan seuraavan k‰sittelem‰ttˆm‰n intensiteetin
    for i = 1:length(intensity_classes)
       if intensity_classes(i) == intensity
           intensity_index = i;
           break 
       end 
    end
end